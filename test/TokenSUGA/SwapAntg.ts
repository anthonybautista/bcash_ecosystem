import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers, upgrades } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { NULL_ADDR } from "../utils";

// when doing multiple calls its not same block so we need to add seconds
async function wait(days: number, secondsToAdd: number = 0): Promise<void> {
  const seconds = days * 24 * 60 * 60 + secondsToAdd;

  await ethers.provider.send("evm_increaseTime", [seconds]);
  await ethers.provider.send("evm_mine", []);
}

describe("Swap antg for sugar", function () {
  let owner: SignerWithAddress,
    addr1: SignerWithAddress,
    addr2: SignerWithAddress,
    addr3: SignerWithAddress,
    Avalant: Contract,
    AntG: Contract,
    Suga: Contract;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const [facAvalant, facAntg, facSuga] = await Promise.all([
      ethers.getContractFactory("contracts/Avalant.sol:Avalant"),
      ethers.getContractFactory("contracts/AntGold.sol:AntGold"),
      ethers.getContractFactory("contracts/Suga.sol:Suga"),
    ]);
    Avalant = await upgrades.deployProxy(
      facAvalant,
      [
        owner.address,
        NULL_ADDR,
        "bite",
        ethers.utils.formatBytes32String(""),
        10,
        4,
      ],
      { initializer: "initialize" }
    );
    AntG = await upgrades.deployProxy(
      facAntg,
      [
        Avalant.address,
        ethers.utils.parseEther("7.5"),
        ethers.utils.parseEther("2.5"),
      ],
      { initializer: "initialize" }
    );
    Suga = await upgrades.deployProxy(
      facSuga,
      [
        Avalant.address,
        AntG.address,
        NULL_ADDR,
        ethers.utils.parseEther("25000000000"),
        18,
        2,
      ],
      { initializer: "initialize" }
    );
    await Avalant.deployed();
    await AntG.deployed();
    await Avalant.openPresale(true);
    await Avalant.openPublic(true);
    await Avalant.setContractAddresses(AntG.address, Suga.address, NULL_ADDR);
    await AntG.setSugaAddress(Suga.address);

    const value = ethers.utils.parseEther("1.2");
    await Avalant.connect(addr3).pickAnts(1, {
      value,
    });
    // addr1 has 1, addr2 has 2.. simple.
    await Avalant.connect(addr1).pickAnts(1, {
      value,
    });
    await Avalant.connect(addr2).pickAnts(1, {
      value,
    });
  });

  it("Should swap Antg for Suga", async function () {
    await AntG.connect(addr1).stakeAnt(1);
    wait(10, 1);
    await AntG.connect(addr1).claimAntGold([1]);
    expect(
      // ANT GOLD
      ethers.utils.formatEther(await AntG.balanceOf(addr1.address)).slice(0, 5)
    ).to.equal("105.0");
    expect(
      // SUGAR
      ethers.utils.formatEther(await Suga.balanceOf(addr1.address)).slice(0, 5)
    ).to.equal("0.0");
    const wantToSwap = ethers.utils.parseEther("100");
    await expect(Suga.connect(addr1).swapAntGForSuga(wantToSwap))
      .to.emit(Suga, "AntGSwap")
      .withArgs(addr1.address, wantToSwap)
      .to.emit(AntG, "Transfer")
      .withArgs(addr1.address, NULL_ADDR, wantToSwap);
    expect(
      // ANT GOLD
      ethers.utils.formatEther(await AntG.balanceOf(addr1.address)).slice(0, 5)
    ).to.equal("5.000");
    expect(
      // SUGAR
      ethers.utils.formatEther(await Suga.balanceOf(addr1.address)).slice(0, 5)
    ).to.equal("1800.");
    await expect(
      Suga.connect(addr1).swapAntGForSuga(wantToSwap)
    ).to.be.revertedWith("ERC20: burn amount exceeds balance");
  });
});
