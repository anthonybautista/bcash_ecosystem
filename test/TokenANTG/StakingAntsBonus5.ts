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

describe("Stake ants for the 5% bonus", function () {
  let owner: SignerWithAddress,
    addr1: SignerWithAddress,
    addr2: SignerWithAddress,
    addr3: SignerWithAddress,
    Avalant: Contract,
    AntG: Contract;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const [facAvalant, facAntg] = await Promise.all([
      ethers.getContractFactory("contracts/Avalant.sol:Avalant"),
      ethers.getContractFactory("AntGold"),
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
    await Avalant.deployed();
    await AntG.deployed();
    await Avalant.openPresale(true);
    await Avalant.openPublic(true);
    await Avalant.setContractAddresses(AntG.address, NULL_ADDR, NULL_ADDR);
    // 1 has 0, 1, 2. 2 has 3, 4, 5.
    await Avalant.connect(addr1).pickAnts(3, {
      value: ethers.utils.parseEther("3.6"),
    });
    await Avalant.connect(addr2).pickAnts(3, {
      value: ethers.utils.parseEther("3.6"),
    });
  });

  it("It should claim 5% more for 10 days", async function () {
    await AntG.connect(addr1).stakeAnts([0, 1, 2]);
    await wait(5, 1);
    await AntG.connect(addr1).claimAntGold([0, 1, 2]);
    const balanceDay5 = await AntG.balanceOf(addr1.address);
    expect(ethers.utils.formatEther(balanceDay5).slice(0, 5)).to.equal("150.0");
    await wait(5, 1);
    await AntG.connect(addr1).claimAntGold([0, 1, 2]);
    const balanceDay10 = await AntG.balanceOf(addr1.address);
    expect(ethers.utils.formatEther(balanceDay10).slice(0, 5)).to.equal(
      "307.5" // would be 300 without the 5% bonus
    );
  });

  it("Should claim more when ant staked for 10 days", async function () {
    // addr1 is gonna stake 10 days, addr2 will not.
    // they will both claim each 2 days tho.
    await AntG.connect(addr1).stakeAnts([0, 1, 2]);
    await AntG.connect(addr2).stakeAnts([3, 4, 5]);
    await wait(5, 1);
    await Avalant.connect(addr2).transferFrom(addr2.address, addr3.address, 3);
    await Avalant.connect(addr2).transferFrom(addr2.address, addr3.address, 4);
    await Avalant.connect(addr2).transferFrom(addr2.address, addr3.address, 5);
    await Avalant.connect(addr3).transferFrom(addr3.address, addr2.address, 3);
    await Avalant.connect(addr3).transferFrom(addr3.address, addr2.address, 4);
    await Avalant.connect(addr3).transferFrom(addr3.address, addr2.address, 5);
    await AntG.connect(addr2).stakeAnts([3, 4, 5]);
    await wait(5, 1);
    await AntG.connect(addr1).claimAntGold([0, 1, 2]);
    await AntG.connect(addr2).claimAntGold([3, 4, 5]);
    expect(
      ethers.utils.formatEther(await AntG.balanceOf(addr1.address)).slice(0, 5)
    ).to.equal(
      "315.0" // would be 300 without the 5% bonus
    );
    expect(
      ethers.utils.formatEther(await AntG.balanceOf(addr2.address)).slice(0, 5)
    ).to.equal(
      "150.0" // burned when selling
    );
  });
});
