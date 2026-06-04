const std = @import("std");

const Rank = enum {
    ace,
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",
    @"10",
    jack,
    queen,
    king,

    const len = std.meta.fields(@This()).len;
};

const Suit = enum {
    club,
    diamond,
    heart,
    spade,

    const len = std.meta.fields(@This()).len;
};

const Card = struct {
    rank: Rank,
    suit: Suit,
};

const Move = struct {};

const Player = struct {
    data: *Data,
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        draft: *const fn (*anyopaque) anyerror![]Card,
        play: *const fn (*anyopaque) anyerror!Card,
    };

    const Data = struct {
        state: union(enum) {
            init,
            deal: struct { is_dealer: bool = false, cards: []Card },
            draft: struct { hand: [4]Card },
            play: struct { hand: []Card, cut_card: Card, pile: []Card },
            show: struct { hand: []Card, cut_card: Card },
        },
        score: u8 = 0,
        crib: ?[4]Card = null,
    };

    fn init(ptr: anytype) Player {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn data(pointer: *anyopaque) *Data {
                const self: T = @ptrCast(@alignCast(pointer));
                return &self.data;
            }

            pub fn draft(pointer: *anyopaque) ![]Card {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.pointer.child.draft(self);
            }

            pub fn play(pointer: *anyopaque) !Card {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.pointer.child.play(self);
            }
        };

        return .{
            .data = gen.data(ptr),
            .ptr = ptr,
            .vtable = &.{
                .draft = gen.draft,
                .play = gen.play,
            },
        };
    }

    pub fn draft(self: Player) ![]Card {
        return self.vtable.draft(self.ptr);
    }

    pub fn play(self: Player) !Card {
        return self.vtable.play(self.ptr);
    }
};

const RandomPlayer = struct {
    data: Player.Data,
    rng: std.Random,

    pub fn init(rng: std.Random) RandomPlayer {
        return .{
            .data = .{ .state = .init },
            .rng = rng,
        };
    }

    fn draft(self: *RandomPlayer) ![]Card {
        const deal = self.data.state.deal;

        var cards = deal.cards;
        self.rng.shuffle(Card, cards);

        const hand = cards[0..4];
        const crib = cards[4..];

        self.data.state = .{ .draft = .{ .hand = hand.* } };

        return crib;
    }

    fn play(self: *RandomPlayer) !Card {
        var hand = self.data.state.play.hand;
        self.rng.shuffle(Card, hand);

        self.data.state.play.hand = hand[1..];

        return hand[0];
    }

    fn player(self: *RandomPlayer) Player {
        return Player.init(self);
    }
};

const HumanPlayer = struct {
    data: Player.Data,
    reader: *std.Io.Reader,

    pub fn init(reader: *std.Io.Reader) HumanPlayer {
        return .{
            .data = .{ .state = .init },
            .reader = reader,
        };
    }

    // FIX: take user input
    fn draft(self: *HumanPlayer) ![]Card {
        const deal = self.data.state.deal;

        var cards = deal.cards;

        const hand = cards[0..4];
        const crib = cards[4..];

        self.data.state = .{ .draft = .{ .hand = hand.* } };

        return crib;
    }

    // FIX: implement
    fn play(self: *HumanPlayer) !Card {
        var hand = self.data.state.play.hand;
        self.data.state.play.hand = hand[1..];

        return hand[0];
    }

    fn player(self: *HumanPlayer) Player {
        return Player.init(self);
    }
};

const Deck = struct {
    buf: [len]Card,
    cards: std.ArrayList(Card),

    const len = Rank.len * Suit.len;

    pub fn pinnedInit(self: *Deck, rng: std.Random) void {
        self.cards = std.ArrayList(Card).initBuffer(&self.buf);
        for (std.enums.values(Rank)) |rank| {
            for (std.enums.values(Suit)) |suit| {
                self.cards.appendAssumeCapacity(.{ .rank = rank, .suit = suit });
            }
        }
        rng.shuffle(Card, self.cards.items);
    }

    pub fn deal(self: *Deck, n: usize) []Card {
        const start = self.cards.items.len - n;
        defer self.cards.items.len -= n;
        return self.cards.items[start..];
    }
};

const Game = struct {
    stdout: *std.Io.Writer,
    p_buf: [max_players]Player,
    players: std.ArrayList(Player),
    state: State,
    deck: Deck,
    dealer: usize,

    const min_players = 2;
    const max_players = 4;

    const State = union(enum) {
        cut,
        deal,
        play: struct {
            active_player: usize,
            cut: Card,
            revealed: []Card = &[_]Card{},
            pile: []Card = &[_]Card{},
        },
        show: struct { active_player: usize },
    };

    pub fn pinnedInit(self: *Game, stdout: *std.Io.Writer, players: []Player) void {
        self.stdout = stdout;
        self.players = .initBuffer(&self.p_buf);

        self.players.appendSliceAssumeCapacity(players);

        self.state = .cut;
    }

    fn cut(self: *Game, rng: std.Random) !void {
        const dealer = rng.uintLessThan(usize, self.players.items.len);
        try self.stdout.print("player {} cut lowest and is dealer\n", .{dealer});
        try self.stdout.flush();

        self.dealer = dealer;
        self.state = .deal;
    }

    fn deal(self: *Game, rng: std.Random) !void {
        self.deck.pinnedInit(rng);

        const num_cards: u8 = switch (self.players.items.len) {
            2 => 6,
            3, 4 => 5,
            else => unreachable,
        };

        var crib_buf: [4]Card = undefined;
        var crib = std.ArrayList(Card).initBuffer(&crib_buf);

        for (self.players.items, 0..) |*player, i| {
            player.data.state = .{ .deal = .{
                .is_dealer = i == self.dealer,
                .cards = self.deck.deal(num_cards),
            } };

            crib.appendSliceAssumeCapacity(try player.draft());
        }

        if (crib.items.len == 3) {
            crib.appendAssumeCapacity(self.deck.deal(1)[0]);
        }

        self.players.items[self.dealer].data.crib = crib.items[0..4].*;

        const cut_card = self.deck.deal(1)[0];
        self.state = .{ .play = .{ .active_player = (self.dealer + 1) % self.players.items.len, .cut = cut_card } };

        if (cut_card.rank == .jack) {
            self.players.items[(self.dealer + 1) % self.players.items.len].data.score += 2;
        }

        for (self.players.items) |*player| {
            var hand = player.data.state.draft.hand;
            player.data.state = .{ .play = .{
                .hand = &hand,
                .cut_card = cut_card,
                .pile = &[_]Card{},
            } };
        }
    }

    fn play(self: *Game) !void {
        const active_player = self.state.play.active_player;

        const card = try self.players.items[active_player].play();
        std.debug.print("{}\n", .{card});

        if (active_player == self.dealer) {
            self.state = .{ .show = .{ .active_player = (self.dealer + 1) % self.players.items.len } };
        } else {
            self.state.play.active_player = (active_player + 1) % self.players.items.len;
        }
    }

    fn show(self: *Game) void {
        _ = self;
    }

    fn round(self: *Game) void {
        _ = self;
    }

    fn turn(self: *Game) void {
        _ = self;
    }
};

pub fn main(init: std.process.Init) !void {
    const rng = (std.Random.IoSource{ .io = init.io }).interface();

    var stdin_buf: [64]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buf);
    const stdin = &stdin_reader.interface;

    var stdout_buf: [64]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    var human = HumanPlayer.init(stdin);
    var ais: [2]RandomPlayer = undefined;
    for (&ais) |*ai| {
        ai.* = .init(rng);
    }

    var players: [3]Player = undefined;
    players[0] = human.player();
    players[1] = ais[0].player();
    players[2] = ais[1].player();

    var game: Game = undefined;
    game.pinnedInit(stdout, &players);

    try game.cut(rng);
    try game.deal(rng);
    try game.play();
}
