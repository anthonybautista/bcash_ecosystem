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

describe("Stake ants and unstake them", function () {
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
    // 1 has 0, 1, 2. 2 has 3, 4, 5, 6. 3 has 7, 8, 10. owner has 9.
    await Avalant.connect(addr1).pickAnts(3, {
      value: ethers.utils.parseEther("3.6"),
    });
    await Avalant.connect(addr2).pickAnts(4, {
      value: ethers.utils.parseEther("4.8"),
    });
    await Avalant.connect(addr3).pickAnts(2, {
      value: ethers.utils.parseEther("2.4"),
    });
    await Avalant.connect(owner).pickAnts(1, {
      value: ethers.utils.parseEther("1.2"),
    });
    await Avalant.connect(addr3).pickAnts(1, {
      value: ethers.utils.parseEther("1.2"),
    });
  });

  it("Should not stake not ur ant", async function () {
    await expect(AntG.connect(addr1).stakeAnts([5])).to.be.revertedWith(
      "Not ur ant"
    );
    await expect(AntG.connect(addr2).stakeAnts([1])).to.be.revertedWith(
      "Not ur ant"
    );
    await expect(AntG.connect(addr3).stakeAnt(3)).to.be.revertedWith(
      "Not ur ant"
    );
    await expect(AntG.connect(owner).stakeAnt(5)).to.be.revertedWith(
      "Not ur ant"
    );
    // should not throw error because it's his ants
    AntG.connect(addr1).stakeAnt(1);
    AntG.connect(addr1).stakeAnt([2]);
  });

  it("Should stake and unstake properly", async function () {
    await expect(
      AntG.connect(addr3).unstakeAntWithoutClaim(1)
    ).to.be.revertedWith("Not ur ant");
    await AntG.connect(addr1).stakeAnts([1]);
    await expect(AntG.connect(addr1).stakeAnts([1])).to.be.revertedWith(
      "Already staked"
    );
    await expect(AntG.connect(addr1).stakeAnts([0, 1, 2])).to.be.revertedWith(
      "Already staked"
    );
    await expect(
      AntG.connect(addr3).unstakeAntWithoutClaim(1)
    ).to.be.revertedWith("Not ur ant");
    // should not throw error
    await AntG.connect(addr1).unstakeAntWithoutClaim(1);
    await expect(
      AntG.connect(addr1).mint(addr1.address, 100)
    ).to.be.revertedWith("Not authorized");
  });

  it("Should gain some ANTG after staking", async function () {
    expect((await AntG.balanceOf(addr1.address)).toNumber()).to.equal(0);
    await AntG.connect(addr1).stakeAnts([1]);
    await wait(1); // one day
    await AntG.connect(addr1).claimAntGold([1]);
    await AntG.connect(addr1).unstakeAntWithoutClaim(1);
    const balance = await AntG.balanceOf(addr1.address);
    expect(ethers.utils.formatEther(balance).slice(0, 5)).to.equal("10.00");
  });

  it("It should claim the right amount for the staked ants", async function () {
    await AntG.connect(addr1).stakeAnts([0, 1, 2]);
    await AntG.connect(addr2).stakeAnts([5, 6]);
    await wait(1, 1); // one day
    const [claimable, claimable2] = await Promise.all([
      AntG.connect(addr1).myClaimableView(),
      AntG.connect(addr2).myClaimableView(),
    ]);
    expect(ethers.utils.formatEther(claimable).slice(0, 5)).to.equal("30.00");
    expect(ethers.utils.formatEther(claimable2).slice(0, 5)).to.equal("20.00");
    await AntG.connect(addr1).claimAntGold([0, 1]);
    const balanceDay1 = await AntG.balanceOf(addr1.address);
    expect(ethers.utils.formatEther(balanceDay1).slice(0, 5)).to.equal("20.00");
    await wait(1);
    const claimable1step2 = await AntG.connect(addr2).myClaimableView();
    expect(ethers.utils.formatEther(claimable1step2).slice(0, 5)).to.equal(
      "40.00" // 2 days * 2 ants -> 40
    );
    await AntG.connect(addr1).claimAntGold([2]);
    await AntG.connect(addr1).unstakeAntWithoutClaim(2);
    const balanceDay2 = await AntG.balanceOf(addr1.address);
    expect(ethers.utils.formatEther(balanceDay2).slice(0, 5)).to.equal("40.00");
    await wait(1);
    const balanceDay3of2 = await AntG.balanceOf(addr2.address);
    expect(ethers.utils.formatEther(balanceDay3of2).slice(0, 5)).to.equal(
      "0.0"
    );
    await AntG.connect(addr2).claimAntGold([5, 6]);
    const balanceDay3of2Afterunstake = await AntG.balanceOf(addr2.address);
    expect(
      ethers.utils.formatEther(balanceDay3of2Afterunstake).slice(0, 5)
    ).to.equal("60.00"); // 2 ants * 3 days
  });

  it("It should claim without unstaking ants", async function () {
    await AntG.connect(addr3).stakeAnts([7, 8, 10]);
    await wait(1, 1); // one day
    const claimable = await AntG.connect(addr3).myClaimableView();
    await AntG.connect(addr3).claimAntGold([7, 8, 10]);
    const balanceDay1 = await AntG.balanceOf(addr3.address);
    expect(ethers.utils.formatEther(balanceDay1).slice(0, 5)).to.equal(
      ethers.utils.formatEther(claimable).slice(0, 5)
    );
    expect(ethers.utils.formatEther(claimable).slice(0, 5)).to.equal("30.00");
    await wait(1, 1); // another day, same thing then..
    const claimable2 = await AntG.connect(addr3).myClaimableView();
    expect(ethers.utils.formatEther(claimable2).slice(0, 5)).to.equal(
      ethers.utils.formatEther(claimable).slice(0, 5)
    );
    await expect(AntG.connect(addr3).stakeAnts([7, 8, 10])).to.be.revertedWith(
      "Already staked"
    );
  });
});
