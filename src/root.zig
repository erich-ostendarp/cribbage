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

const PlayerData = struct { a: u8 };

const Player = struct {
    data: PlayerData,
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        getMove: *const fn (*anyopaque) Move,
        getLegalMoves: *const @TypeOf(getLegalMoves) = getLegalMoves,
    };

    fn init(ptr: anytype) Player {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn data(pointer: *anyopaque) PlayerData {
                const self: T = @ptrCast(@alignCast(pointer));
                return self.data;
            }

            pub fn getMove(pointer: *anyopaque) Move {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.pointer.child.getMove(self);
            }
        };

        return .{
            .data = gen.data(ptr),
            .ptr = ptr,
            .vtable = &.{
                .getMove = gen.getMove,
                .getLegalMoves = getLegalMoves,
            },
        };
    }

    pub fn getMove(self: Player) Move {
        return self.vtable.getMove(self.ptr);
    }

    pub fn getLegalMoves(self: Player) []const Move {
        _ = self;
        return &.{ .{}, .{}, .{} };
    }
};

const RandomPlayer = struct {
    data: PlayerData,

    fn getMove(self: *RandomPlayer) Move {
        _ = self;
        return .{};
    }

    fn player(self: *RandomPlayer) Player {
        return Player.init(self);
    }
};

const HumanPlayer = struct {
    data: PlayerData,
    reader: *std.Io.Reader,

    pub fn init(reader: *std.Io.Reader) HumanPlayer {
        return .{
            .data = .{ .a = 0 },
            .reader = reader,
        };
    }

    fn getMove(self: *HumanPlayer) Move {
        const line = self.reader.takeDelimiter('\n') catch return .{};
        std.debug.print("{s}\n", .{line.?});
        return .{};
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

const Board = struct {};

const GameState = union(enum) {
    init,
};

const Game = struct {
    p_buf: [max_players]Player,
    players: std.ArrayList(Player),
    deck: Deck,
    board: Board,
    state: GameState,

    const min_players = 2;
    const max_players = 6;

    pub fn pinnedInit(self: *Game, rng: std.Random, stdin: *std.Io.Reader, num_players: usize) void {
        self.players = .initBuffer(&self.p_buf);

        var human = HumanPlayer.init(stdin);
        var p = human.player();
        self.players.appendAssumeCapacity(p);
        for (0..num_players - 1) |_| {
            var ai = RandomPlayer{ .data = .{ .a = 2 } };
            p = ai.player();
            self.players.appendAssumeCapacity(p);
        }

        self.deck.pinnedInit(rng);
        self.board = Board{};
        self.state = .init;
    }
};

pub fn main(init: std.process.Init) !void {
    const rng = (std.Random.IoSource{ .io = init.io }).interface();

    var stdin_buf: [64]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buf);
    const stdin = &stdin_reader.interface;

    var game: Game = undefined;
    game.pinnedInit(rng, stdin, 2);

    _ = game.players.items[0].getMove();
}
