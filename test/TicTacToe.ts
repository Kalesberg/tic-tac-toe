import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("TicTacToe", function () {
  async function deployContractFixture() {
    const [user1, user2, user3] = await hre.ethers.getSigners();

    const TicTacToe = await hre.ethers.getContractFactory("TicTacToe");
    const contract = await TicTacToe.deploy();

    return { contract, user1, user2, user3 };
  }

  it("Create and start game", async function () {
    const { contract, user1, user2, user3 } = await loadFixture(deployContractFixture);

    expect(await contract.nonce()).to.equals(0);

    const pairId = await contract.getPairId(user1, user2);
    const gameId = await contract.getGameId(pairId, 0);

    await expect(contract.connect(user1).createGame(user2))
      .to.emit(contract, "GameCreated")
      .withArgs(gameId, user1, user2);

    expect(await contract.nonce()).to.equals(1);

    await expect(contract.connect(user2).createGame(user1))
      .to.be.revertedWith("Already invited");

    await expect(contract.connect(user3).acceptInvite(pairId))
      .to.be.revertedWith("Not invited");

    await contract.connect(user2).acceptInvite(pairId);
    const game = await contract.games(gameId);
    expect(game.status).to.equals(1);

    await contract.connect(user2).createGame(user3);
    expect(await contract.nonce()).to.equals(2);
  });

  it("Play game", async function() {
    const { contract, user1, user2, user3 } = await loadFixture(deployContractFixture);

    const pairId = await contract.getPairId(user1, user2);
    const gameId = await contract.getGameId(pairId, 0);

    await contract.connect(user1).createGame(user2);
    await expect(contract.connect(user2).acceptInvite(pairId))
      .to.emit(contract, "GameStarted")
      .withArgs(gameId);

    /**
      - - -     - - -    - - -    - - x    - - x    - x x    o o x
      - - -     - - x    - o x    - o x    - o x    - o x    - o x
      - - -     - - -    - - -    - - -    - - o    - - o    - - o
    */
    await expect(contract.connect(user3).tick(gameId, 1, 1))
      .to.be.revertedWith("Invalid player");
    await expect(contract.connect(user2).tick(gameId, 1, 1))
      .to.be.revertedWith("Not player turn");
    await expect(contract.connect(user1).tick(gameId, 0, 0))
      .to.be.revertedWith("Invalid tick");

    await contract.connect(user1).tick(gameId, 2, 3);
    await expect(contract.connect(user2).tick(gameId, 2, 3))
      .to.be.revertedWith("Duplicate tick");
    await contract.connect(user2).tick(gameId, 2, 2);
    await contract.connect(user1).tick(gameId, 1, 3);
    await contract.connect(user2).tick(gameId, 3, 3);
    await contract.connect(user1).tick(gameId, 1, 2);
    await expect(contract.connect(user2).tick(gameId, 1, 1))
      .to.emit(contract, "GameEnded")
      .withArgs(gameId, user2);
    await expect(contract.connect(user1).tick(gameId, 1, 2))
      .to.be.revertedWith("Game over");
  });
});
