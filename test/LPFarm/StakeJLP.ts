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

describe("JLP Tests", function () {
  let owner: SignerWithAddress,
    addr1: SignerWithAddress,
    addr2: SignerWithAddress,
    addr3: SignerWithAddress,
    LPFarm: Contract,
    BCash: Contract,
    JLP: Contract;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const [facLPFarm, facBCash, facMockJLP] = await Promise.all([
      ethers.getContractFactory("contracts/LPFarm.sol:bCashLPFarm"),
      ethers.getContractFactory("contracts/bCash.sol:ButterflyCash"),
      ethers.getContractFactory("contracts/MockJLP.sol:MockJLP"),
    ]);

    BCash = await facBCash.deploy();
    JLP = await facMockJLP.deploy();
    LPFarm = await facLPFarm.deploy(JLP.address,BCash.address);

    await BCash.deployed();
    await JLP.deployed();
    await LPFarm.deployed();

    await JLP.mint(addr1.address, powTen18("1"));

    await JLP.mint(addr2.address, powTen18("5"));

    await JLP.mint(addr3.address, powTen18("2"));

    await BCash.addMintingCaller(LPFarm.address);

    
  });

  it("Check that JLP tokens are minted to addresses", async function () {
    let balance1 = await JLP.balanceOf(addr1.address);
    expect(balance1.toString().slice(0, 5)).to.equal(
      "10000"
    );
    let balance2 = await JLP.balanceOf(addr2.address);
    expect(balance2.toString().slice(0, 5)).to.equal(
      "50000"
    );
    let balance3 = await JLP.balanceOf(addr3.address);
    expect(balance3.toString().slice(0, 5)).to.equal(
      "20000"
    );
  });

  it("Check JLP supply and wavax reserves", async function () {
    let supply = await JLP.totalSupply();
    expect(supply.toString().slice(0, 5)).to.equal(
      powTen18("8").toString().slice(0, 5)
    );
    const [resWAVAX, resBCash, time] = await JLP.getReserves();
    expect(resWAVAX.toString().slice(0, 5)).to.equal(
      powTen18("1000").toString().slice(0, 5)
    );
  });

  it("Should fail to stake without approval or amount == 0", async function () {
    // stake JLP
    
    await expect(
      LPFarm.connect(addr1).stakeLP(powTen18("0"))
    ).to.be.revertedWith("Amount must be greater than 0");
    
    await expect(
      LPFarm.connect(addr1).stakeLP(powTen18("1"))
    ).to.be.revertedWith("ERC20: insufficient allowance");
    
    await expect(
      LPFarm.connect(addr2).stakeLP(powTen18("5"))
    ).to.be.revertedWith("ERC20: insufficient allowance");
    
  });

  it("Unstaking should fail because of amount or not enough staked", async function () {
    // stake JLP
    await JLP.connect(addr1).approve(LPFarm.address, powTen18("1"));
    await LPFarm.connect(addr1).stakeLP(powTen18("1"));
    await expect(
      LPFarm.connect(addr1).unstakeLP(powTen18("0"))
    ).to.be.revertedWith("Amount must be greater than 0"); 
    
    await expect(
      LPFarm.connect(addr2).unstakeLP(powTen18("5"))
    ).to.be.revertedWith("Not enough LP staked");
    
  });

  it("Should stake JLP for bCASH", async function () {
    // approve use of JLP token
    await JLP.connect(addr1).approve(LPFarm.address, powTen18("1"));
    await JLP.connect(addr2).approve(LPFarm.address, powTen18("5"));

    await LPFarm.connect(addr1).stakeLP(powTen18("1"));
    let wavax1 = await LPFarm.wavaxView(addr1.address);
    wavax1 = ethers.utils.formatEther(wavax1);
    expect(wavax1.toString().slice(0, 3)).to.equal(
      powTen18("125").toString().slice(0, 3)
    );
    await LPFarm.connect(addr2).stakeLP(powTen18("5"))
    let wavax2 = await LPFarm.wavaxView(addr2.address);
    wavax2 = ethers.utils.formatEther(wavax2);
    expect(wavax2.toString().slice(0, 3)).to.equal(
      powTen18("625").toString().slice(0, 3)
    ); 

    await wait(0.5, 1); // day 0 - 12 hours.
    const claimable = await LPFarm.claimableView(addr1.address);
    expect(claimable.toString().slice(0, 3)).to.equal(
      (wavax1 * 2).toString().slice(0, 3)
    );
    await wait(0.5, 1); // day 1
    await LPFarm.connect(addr1).claimBCash();
    // day 1 -> 200 (125 * 4)
    const balance = await BCash.balanceOf(addr1.address);
    expect(balance.toString().slice(0, 3)).to.equal(
      (wavax1 * 4).toString().slice(0, 3)
    );
    const claimable2 = await LPFarm.claimableView(addr1.address);
    expect(claimable2.toString().slice(0, 5)).to.equal(
      powTen18("0").toString().slice(0, 5)
    );
    await wait(1, 1); // day 2
    await LPFarm.connect(addr2).claimBCash();
    // day 1 -> (625*4 = 2500), day 2 -> (625*4 = 2500). (2500*2)
    expect(
      (await BCash.balanceOf(addr2.address)).toString().slice(0, 4)
    ).to.equal(powTen18("5000").toString().slice(0, 4));
    await wait(1, 1); // day 3 (125 * 4 * 3)
    
    // unstake and check new Suga balance as well as JLP balance
    await expect(LPFarm.connect(addr1).unstakeLP(powTen18("1")))
      .to.emit(LPFarm, "UnstakedLP")
      .withArgs(addr1.address, powTen18("1")) // pof 10% burned
      .to.emit(JLP, "Transfer")
      .withArgs(LPFarm.address, addr1.address, powTen18("1"));
    expect(
      (await BCash.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("150").toString().slice(0, 4));
    expect(
      (await JLP.balanceOf(addr1.address)).toString().slice(0, 4)
    ).to.equal(powTen18("1").toString().slice(0, 4));
  });

  it("wavax calculations should change when reserves change", async function () {
    // approve use of JLP token
    await JLP.connect(addr1).approve(LPFarm.address, powTen18("1"));
    await JLP.connect(addr2).approve(LPFarm.address, powTen18("5"));

    // stake JLP, watch for events, and check wavax equivalent
    await LPFarm.connect(addr1).stakeLP(powTen18("1"));
    let wavax1 = await LPFarm.wavaxView(addr1.address);
    wavax1 = ethers.utils.formatEther(wavax1);
    expect(wavax1.toString().slice(0, 3)).to.equal(
      powTen18("125").toString().slice(0, 3)
    );

    await LPFarm.connect(addr2).stakeLP(powTen18("5"));
    let wavax2 = await LPFarm.wavaxView(addr2.address);
    wavax2 = ethers.utils.formatEther(wavax2);
    expect(wavax2.toString().slice(0, 3)).to.equal(
      powTen18("625").toString().slice(0, 3)
    ); 

    // double wavax reserves
    await JLP.connect(owner).updateReserves(2000, 1000000);
    let newWavax1 = await LPFarm.wavaxView(addr1.address);
    newWavax1 = ethers.utils.formatEther(newWavax1);
    let newWavax2 = await LPFarm.wavaxView(addr2.address);
    newWavax2 = ethers.utils.formatEther(newWavax2);
    expect(newWavax1.toString().slice(0, 3))
      .to.equal((wavax1 * 2).toString().slice(0, 3));
    expect(newWavax2.toString().slice(0, 3))
      .to.equal((wavax2 * 2).toString().slice(0, 3));
  });

  it("Should claim for all stakers", async () => {
    await JLP.connect(addr1).approve(LPFarm.address, powTen18("1"));
    await JLP.connect(addr2).approve(LPFarm.address, powTen18("5"));

    await LPFarm.connect(addr1).stakeLP(powTen18("1"));
    await LPFarm.connect(addr2).stakeLP(powTen18("5"));
    expect(await LPFarm.getAmountOfStakers()).to.equal(2);
    await LPFarm.connect(addr1).unstakeLP(powTen18("1"));
    expect(await LPFarm.getAmountOfStakers()).to.equal(1);
    expect(await LPFarm.LPStakers(0)).to.equal(addr2.address);
    wait(1);
    expect(await LPFarm.claimForPeople(0, 0)).to.emit(JLP, "Transfer");
    await expect(LPFarm.connect(addr1).claimForPeople(0, 0)).to.be.reverted;
    expect(
      ethers.utils.formatEther(await BCash.balanceOf(addr2.address)).slice(0, 4)
    ).to.equal("2500");
  });

});
