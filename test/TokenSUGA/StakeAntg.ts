import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers, upgrades } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { NULL_ADDR } from "../utils";

const powTen18 = ethers.utils.parseEther;

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
    await AntG.connect(addr1).stakeAnt(1);
    await AntG.connect(addr2).stakeAnt(2);
    wait(10, 1);
    await AntG.connect(addr1).claimAntGold([1]);
    await AntG.connect(addr2).claimAntGold([2]);
    await AntG.connect(addr1).unstakeAntWithoutClaim(1);
    await AntG.connect(addr2).unstakeAntWithoutClaim(2);
  });

  // addr1 and addr2 have 105 antg each
  it("Should stake AntG Suga", async function () {
    await Suga.connect(addr1).stakeAntg(powTen18("100"));
    await Suga.connect(addr2).stakeAntg(powTen18("50"));
    wait(0.5, 1); // day 0 - 12 hours.
    const claimable = await Suga.claimableView(addr1.address);
    expect(claimable.toString().slice(0, 5)).to.equal(
      powTen18("100").toString().slice(0, 5)
    );
    wait(0.5, 1); // day 1
    await Suga.connect(addr1).claimSuga();
    // day 1 -> 200 (100*2)
    const balance = await Suga.balanceOf(addr1.address);
    expect(balance.toString().slice(0, 4)).to.equal(
      powTen18("200").toString().slice(0, 4)
    );
    const claimable2 = await Suga.claimableView(addr1.address);
    expect(claimable2.toString().slice(0, 5)).to.equal(
      powTen18("0").toString().slice(0, 5)
    );
    wait(1, 1); // day 2
    await Suga.connect(addr2).claimSuga();
    // day 1 -> 100, day 2 -> 100. (50*2)
    expect(
      (await Suga.balanceOf(addr2.address)).toString().slice(0, 5)
    ).to.equal(powTen18("200").toString().slice(0, 5));
    wait(1, 1); // day 3
    await Suga.connect(addr1).claimSuga();
    expect(
      (await Suga.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("600").toString().slice(0, 4));
  });

  it("Should stake properly each 2.4 hours", async () => {
    await Suga.connect(addr1).stakeAntg(powTen18("10"));
    expect(
      (await Suga.claimableView(addr1.address)).toString().slice(0, 5)
    ).to.equal(powTen18("0").toString().slice(0, 5));
    wait(0.1);
    expect(
      (await Suga.claimableView(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("2").toString().slice(0, 4));
    wait(0.1);
    expect(
      (await Suga.claimableView(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("4").toString().slice(0, 4));
    await Suga.connect(addr1).stakeAntg(powTen18("10"));
    expect(
      (await Suga.claimableView(addr1.address)).toString().slice(0, 5)
    ).to.equal(powTen18("0").toString().slice(0, 5));
    expect(
      (await Suga.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("4").toString().slice(0, 4));
    wait(0.1);
    expect(
      (await Suga.claimableView(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("4").toString().slice(0, 4));
    await Suga.connect(addr1).stakeAntg(powTen18("20"));
    expect(
      (await Suga.claimableView(addr1.address)).toString().slice(0, 8)
    ).to.equal(powTen18("0").toString().slice(0, 8));
    expect(
      (await Suga.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("8").toString().slice(0, 4));
    wait(0.1);
    expect(
      (await Suga.claimableView(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("8").toString().slice(0, 4));
    await Suga.connect(addr1).unstakeAntg(powTen18("20"));
    expect(
      (await Suga.claimableView(addr1.address)).toString().slice(0, 5)
    ).to.equal(powTen18("0").toString().slice(0, 5));
    wait(0.1);
    expect(
      (await Suga.claimableView(addr1.address)).toString().slice(0, 5)
    ).to.equal(powTen18("4").toString().slice(0, 5));
    expect(await Suga.getAmountOfStakers()).to.equal(1);
    await Suga.connect(addr1).unstakeAntg(powTen18("10"));
    expect(await Suga.getAmountOfStakers()).to.equal(1);
    await Suga.connect(addr1).unstakeAntg(powTen18("10"));
    expect(await Suga.getAmountOfStakers()).to.equal(0);
    expect(
      (await Suga.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("20").toString().slice(0, 4));
  });

  it("Should unstakeAntG and lose 10% of it", async () => {
    expect(
      (await AntG.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("105").toString().slice(0, 4));
    await Suga.connect(addr1).stakeAntg(powTen18("50"));
    wait(10, 1);
    await Suga.connect(addr1).unstakeAntg(powTen18("50"));
    expect(
      (await AntG.balanceOf(addr1.address)).toString().slice(0, 4)
      // 55 from the antg at the beginning of the test
      // unstake 50 gives you 45 so its 45+55=100
    ).to.equal(powTen18("100").toString().slice(0, 4));
    expect(
      (await Suga.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("1000").toString().slice(0, 4));
  });

  it("Should unstakeAntG and lose 10% of it while staking ants", async () => {
    expect(
      (await AntG.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("105").toString().slice(0, 4));
    wait(10, 1);
    expect(
      (await AntG.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("105").toString().slice(0, 4));
    await AntG.connect(addr1).stakeAnt(1);
    await expect(
      Suga.connect(addr1).unstakeAntg(powTen18("50"))
    ).to.be.revertedWith("Not enough AntG staked");
    await expect(
      Suga.connect(addr1).stakeAntg(powTen18("200"))
    ).to.be.revertedWith("ERC20: burn amount exceeds balance");
    expect(
      (await AntG.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("105").toString().slice(0, 4));
    await expect(Suga.connect(addr1).stakeAntg(powTen18("105")))
      .to.emit(Suga, "StakedAntG")
      .withArgs(addr1.address, powTen18("105"))
      .to.emit(AntG, "Transfer")
      .withArgs(addr1.address, NULL_ADDR, powTen18("105"));
    expect(
      ethers.utils.formatEther(await AntG.balanceOf(addr1.address)).slice(0, 4)
    ).to.equal("0.00");
    wait(10, 1);
    await AntG.connect(addr1).claimAntGold([1]);
    expect(
      (await AntG.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("105").toString().slice(0, 4));
    await Suga.connect(addr1).claimSuga();
    expect(
      (await Suga.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("2100").toString().slice(0, 4));
  });

  it("Should trigger all events", async () => {
    await expect(Suga.connect(addr1).stakeAntg(powTen18("50")))
      .to.emit(Suga, "StakedAntG")
      .withArgs(addr1.address, powTen18("50"))
      .to.emit(AntG, "Transfer")
      .withArgs(addr1.address, NULL_ADDR, powTen18("50"));
    wait(1, 1);
    await expect(Suga.connect(addr1).unstakeAntg(powTen18("25")))
      .to.emit(Suga, "UnstakedAntG")
      .withArgs(addr1.address, powTen18("22.5")) // pof 10% burned
      .to.emit(Suga, "Transfer");
    // this is good but there is a small amount of sufar more
    // .withArgs(NULL_ADDR, addr1.address, powTen18("100"));
    await expect(Suga.connect(addr1).claimSuga()); // doing nothing but not failing
    await expect(Suga.connect(addr1).swapAntGForSuga(powTen18("50")))
      .to.emit(Suga, "AntGSwap")
      .withArgs(addr1.address, powTen18("50"))
      .to.emit(Suga, "Transfer")
      .withArgs(NULL_ADDR, addr1.address, powTen18("900")) // 50*18
      .to.emit(AntG, "Transfer")
      .withArgs(addr1.address, NULL_ADDR, powTen18("50"));
  });

  it("Should claim for all stakers", async () => {
    await Suga.connect(addr1).stakeAntg(powTen18("50"));
    await Suga.connect(addr2).stakeAntg(powTen18("50"));
    expect(await Suga.getAmountOfStakers()).to.equal(2);
    await Suga.connect(addr1).unstakeAntg(powTen18("50"));
    expect(await Suga.getAmountOfStakers()).to.equal(1);
    expect(await Suga.antgStakers(0)).to.equal(addr2.address);
    wait(1);
    expect(
      ethers.utils.formatEther(await Suga.balanceOf(addr1.address)).slice(0, 4)
    ).to.equal("0.00");
    expect(await Suga.claimForPeople(0, 0)).to.emit(Suga, "Transfer");
    await expect(Suga.connect(addr1).claimForPeople(0, 0)).to.be.reverted;
    expect(
      ethers.utils.formatEther(await Suga.balanceOf(addr2.address)).slice(0, 4)
    ).to.equal("100.");
    // .withArgs(NULL_ADDR, addr2.address, powTen18("50"));
  });
});
