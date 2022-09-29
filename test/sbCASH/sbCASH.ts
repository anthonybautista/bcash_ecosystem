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

describe("Staking Tests", function () {
  let owner: SignerWithAddress,
    addr1: SignerWithAddress,
    addr2: SignerWithAddress,
    addr3: SignerWithAddress,
    sbCASH: Contract,
    BCash: Contract;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const [facsbCASH, facBCash] = await Promise.all([
      ethers.getContractFactory("contracts/sbCASH.sol:StakedButterflyCash"),
      ethers.getContractFactory("contracts/bCash.sol:ButterflyCash"),
    ]);

    BCash = await facBCash.deploy();
    sbCASH = await facsbCASH.deploy();

    await BCash.deployed();
    await sbCASH.deployed();

    await BCash.addMintingCaller(owner.address);

    await BCash.connect(owner).mint(owner.address, 1000000);

    await BCash.connect(owner).stake();

    await BCash.connect(owner).mint(addr1.address, 10000);

    await BCash.connect(owner).mint(addr2.address, 70000);

    await BCash.connect(owner).mint(addr3.address, 20000);

    await BCash.addLP(sbCASH.address);

    await sbCASH.setBC(BCash.address);

    
  });

  it("Check that bCASH tokens are minted to addresses", async function () {
    let balance1 = await BCash.balanceOf(addr1.address);
    expect(balance1.toString().slice(0, 5)).to.equal(
      "10000"
    );
    let balance2 = await BCash.balanceOf(addr2.address);
    expect(balance2.toString().slice(0, 5)).to.equal(
      "70000"
    );
    let balance3 = await BCash.balanceOf(addr3.address);
    expect(balance3.toString().slice(0, 5)).to.equal(
      "20000"
    );
  });

  it("Should fail to stake without approval or amount < 10k", async function () {
    // stake JLP
    
    await expect(
      sbCASH.connect(addr1).stake(powTen18("5000"))
    ).to.be.revertedWith("Minimum stake is 10k $bCASH!");
    
    await expect(
      sbCASH.connect(addr1).stake(powTen18("10000"))
    ).to.be.revertedWith("ERC20: insufficient allowance");
    
    await expect(
      sbCASH.connect(addr2).stake(powTen18("50000"))
    ).to.be.revertedWith("ERC20: insufficient allowance");
    
  });

  it("Unstaking should fail because cooldown not done or nothing staked", async function () {
    // stake JLP
    await BCash.connect(addr2).approve(sbCASH.address, powTen18("70000"));
    await sbCASH.connect(addr2).stake(powTen18("10000"));
    await expect(
      sbCASH.connect(addr2).unStake()
    ).to.be.revertedWith("Stake not done yet!"); 

    await wait(5, 1); // 5 days

    await expect(
      sbCASH.connect(addr2).unStake()
    ).to.be.revertedWith("Stake not done yet!"); 

    // stake again and restart cooldown
    await sbCASH.connect(addr2).stake(powTen18("10000"));

    await wait(3, 1); // 8 days

    await expect(
      sbCASH.connect(addr2).unStake()
    ).to.be.revertedWith("Stake not done yet!"); 

    await wait(3, 1); // 11 days

    await expect(
      sbCASH.connect(addr2).unStake()
    ).to.be.revertedWith("Stake not done yet!");

    await wait(2,1) // 13 days

    await sbCASH.connect(addr2).unStake();

    await expect(
      sbCASH.connect(addr2).unStake()
    ).to.be.revertedWith("Nothing to unStake!");

  });

  it("Should stake bCASH for sbCASH and allow claiming after cooldown", async function () {
    // approve use of JLP token
    await BCash.connect(addr1).approve(sbCASH.address, powTen18("10000"));
    await BCash.connect(addr2).approve(sbCASH.address, powTen18("70000"));
    await BCash.connect(addr3).approve(sbCASH.address, powTen18("20000"));

    await sbCASH.connect(addr1).stake(powTen18("10000"));
    let [_sbCASH, _bCASH] = await sbCASH.totalView();
    expect(_sbCASH.toString()).to.equal(
      powTen18("10000")
    );
    expect(_bCASH.toString()).to.equal(
      powTen18("10000")
    );

    await sbCASH.connect(addr2).stake(powTen18("60000"));
    let [_sbCASH2, _bCASH2] = await sbCASH.totalView();
    expect(_sbCASH2.toString()).to.equal(
      powTen18("70000")
    );
    expect(_bCASH2.toString()).to.equal(
      powTen18("70000")
    );

    expect(await sbCASH.getShareFor(addr1.address)).to.equal(
      powTen18("10000")
    );

    expect(await sbCASH.getShareFor(addr2.address)).to.equal(
      powTen18("60000")
    );

    await BCash.connect(addr3).transfer(sbCASH.address,powTen18("20000"));

    let [_sbCASH3, _bCASH3] = await sbCASH.totalView();
    expect(_sbCASH3.toString()).to.equal(
      powTen18("70000")
    );
    expect(_bCASH3.toString()).to.equal(
      powTen18("90000")
    );

    await wait(7, 1); // 7 days
    await sbCASH.connect(addr2).stake(powTen18("10000"));
    let [_sbCASH4, _bCASH4] = await sbCASH.totalView();
    expect(_sbCASH4.toString()).to.equal(
      powTen18("80000")
    );
    expect(_bCASH4.toString()).to.equal(
      powTen18("100000")
    );

    expect(await sbCASH.getShareFor(addr1.address)).to.equal(
      powTen18("12500")
    );

    expect(await sbCASH.getShareFor(addr2.address)).to.equal(
      powTen18("87500")
    );

    await sbCASH.connect(addr1).unStake();

    expect(await sbCASH.getShareFor(addr1.address)).to.equal(
      powTen18("0")
    );

    let [_sbCASH5, _bCASH5] = await sbCASH.totalView();
    expect(_sbCASH5.toString()).to.equal(
      powTen18("70000")
    );
    expect(_bCASH5.toString()).to.equal(
      powTen18("87500")
    );

    expect(await sbCASH.getShareFor(addr2.address)).to.equal(
      powTen18("87500")
    );

    await wait(7, 1); // day 14

    await sbCASH.connect(addr2).unStake();

    let [_sbCASH6, _bCASH6] = await sbCASH.totalView();
    expect(_sbCASH6.toString()).to.equal(
      powTen18("0")
    );
    expect(_bCASH6.toString()).to.equal(
      powTen18("0")
    );

    expect(await sbCASH.getShareFor(addr2.address)).to.equal(
      powTen18("0")
    );
  });

});
