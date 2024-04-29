// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract TicTacToe {
    struct Game {
        int8[9] board; // 1: playerA, -1: playerB
        uint8 status;   // 0 - not started, 1 - started, 2 - draw, 3 - playerA won, 4 - playerB won
        bool turn;  // true - playerA's turn, false - playerB's turn
        address playerA;    // initiator
        address playerB;    // invitee
    }

    struct GameInvite {
        bytes32 gameId;
        address invitee;
    }

    event GameCreated(bytes32 indexed gameId, address indexed playerA, address indexed playerB);
    event GameStarted(bytes32 indexed gameId);
    event GameDraw(bytes32 indexed gameId);
    event GameEnded(bytes32 indexed gameId, address indexed winner);

    // gameId -> Game
    mapping (bytes32 => Game) public games;
    // pairId -> GameInvite
    mapping (bytes32 => GameInvite) public invites;
    // grows as new games created
    uint256 public nonce;

    function createGame(address invitee) external
    {
        address initiator = msg.sender;
        require(invitee != address(0) && initiator != invitee, "Invalid invitee");

        bytes32 pairId = _getPairId(initiator, invitee);
        require(invites[pairId].invitee == address(0), "Already invited");

        bytes32 gameId = _getGameId(pairId, nonce);
        Game memory game = Game({
            board: [int8(0), int8(0), int8(0), int8(0), int8(0), int8(0), int8(0), int8(0), int8(0)],
            status: 0,
            turn: uint256(pairId) >> 255 == 1,
            playerA: initiator,
            playerB: invitee
        });
        GameInvite memory gameInvite = GameInvite({
            gameId: gameId,
            invitee: invitee
        });

        games[gameId] = game;
        invites[pairId] = gameInvite;
        nonce ++;

        emit GameCreated(gameId, initiator, invitee);
    }

    function acceptInvite(bytes32 pairId) external
    {
        require(msg.sender == invites[pairId].invitee, "Not invited");

        bytes32 gameId = invites[pairId].gameId;
        Game storage game = games[gameId];
        game.status = 1;

        delete invites[pairId];
        emit GameStarted(gameId);
    }

    function tick(bytes32 gameId, uint256 colNum, uint256 rowNum) external
    {
        address player = msg.sender;

        _gameInProgress(gameId);
        _validTurn(gameId, msg.sender);
        require(colNum >=1 && colNum <= 3 && rowNum >=1 && rowNum <= 3, "Invalid tick");

        Game memory game = games[gameId];
        uint256 boardIndex = 3 * (colNum - 1) + (rowNum - 1);

        if (game.board[boardIndex] > 0) revert("Duplicate tick");

        game.board[boardIndex] = player == game.playerA ? int8(1) : -1;
        game.turn = !game.turn;

        uint8 status = _checkGameStatus(game.board);
        game.status = status;
        games[gameId] = game;

        if (status == 2) {
            emit GameDraw(gameId);
        } else if (status == 3) {
            emit GameEnded(gameId, game.playerA);
        } else if (status == 4) {
            emit GameEnded(gameId, game.playerB);
        }
    }

    function getPairId(address playerA, address playerB) external pure returns (bytes32)
    {
        return _getPairId(playerA, playerB);
    }

    function getGameId(bytes32 pairId, uint256 entropy) external pure returns (bytes32)
    {
        return _getGameId(pairId, entropy);
    }

    function _getPairId(address playerA, address playerB) internal pure returns (bytes32)
    {
        (address one, address two) = (playerA > playerB) ? (playerA, playerB) : (playerB, playerA);
        return keccak256(abi.encodePacked(one, two));
    }

    function _getGameId(bytes32 pairId, uint256 entropy) internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(pairId, entropy));
    }

    function _gameInProgress(bytes32 gameId) internal view
    {
        Game memory game = games[gameId];
        if (game.status == 0) revert("Game not started");
        else if (game.status > 1) revert("Game over");
    }

    function _validTurn(bytes32 gameId, address player) internal view
    {
        Game memory game = games[gameId];

        require(player == game.playerA || player == game.playerB, "Invalid player");
        require((player == game.playerA && game.turn) || (player == game.playerB && !game.turn), "Not player turn");
    }

    function _checkGameStatus(int8[9] memory board) internal pure returns (uint8)
    {
        if (
            (board[0] + board[1] + board[2] == 3) ||
            (board[3] + board[4] + board[5] == 3) ||
            (board[6] + board[7] + board[8] == 3) ||
            (board[0] + board[3] + board[6] == 3) ||
            (board[1] + board[4] + board[7] == 3) ||
            (board[2] + board[5] + board[8] == 3) ||
            (board[0] + board[4] + board[8] == 3) ||
            (board[2] + board[4] + board[6] == 3)
        ) {
            return 3;   // PlayerA won
        } else if (
            (board[0] + board[1] + board[2] == -3) ||
            (board[3] + board[4] + board[5] == -3) ||
            (board[6] + board[7] + board[8] == -3) ||
            (board[0] + board[3] + board[6] == -3) ||
            (board[1] + board[4] + board[7] == -3) ||
            (board[2] + board[5] + board[8] == -3) ||
            (board[0] + board[4] + board[8] == -3) ||
            (board[2] + board[4] + board[6] == -3)
        ) {
            return 4;   // PlayerB won
        } else if (
            board[0] != 0 &&
            board[1] != 0 &&
            board[2] != 0 &&
            board[3] != 0 &&
            board[4] != 0 &&
            board[5] != 0 &&
            board[6] != 0 &&
            board[7] != 0 &&
            board[8] != 0
        ) {
            return 2;   // Game draw
        }

        return 1;   // Game in progres
    }
}
