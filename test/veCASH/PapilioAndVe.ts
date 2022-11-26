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

describe("Papilio & veCASH Tests", function () {
  let owner: SignerWithAddress,
    addr1: SignerWithAddress,
    addr2: SignerWithAddress,
    addr3: SignerWithAddress,
    LPFarm: Contract,
    LPFarm2: Contract,
    BCash: Contract,
    veCash: Contract,
    nft: Contract,
    ppmp: Contract,
    JLP: Contract;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const [facLPFarm, facLPFarm2, facBCash, facMockJLP, facVeCash, facNFT, facPPMP] = await Promise.all([
      ethers.getContractFactory("contracts/LPFarm.sol:bCashLPFarm"),
      ethers.getContractFactory("contracts/LPFarm.sol:bCashLPFarm"),
      ethers.getContractFactory("contracts/bCash.sol:ButterflyCash"),
      ethers.getContractFactory("contracts/MockJLP.sol:MockJLP"),
      ethers.getContractFactory("contracts/veCASH.sol:veCASH"),
      ethers.getContractFactory("contracts/PapilioPalatia.sol:PapilioPalatia"),
      ethers.getContractFactory("contracts/PPMP.sol:PapilioMintPass"),
    ]);

    BCash = await facBCash.deploy();
    JLP = await facMockJLP.deploy();
    LPFarm = await facLPFarm.deploy(JLP.address,BCash.address);
    LPFarm2 = await facLPFarm2.deploy(JLP.address,BCash.address);
    veCash = await facVeCash.deploy();
    nft = await facNFT.deploy();
    ppmp = await facPPMP.deploy();

    await BCash.deployed();
    await JLP.deployed();
    await LPFarm.deployed();
    await LPFarm2.deployed();
    await veCash.deployed();
    await nft.deployed();
    await ppmp.deployed();

    // mint LP tokens to addresses
    await JLP.mint(addr1.address, powTen18("10"));
    await JLP.mint(addr2.address, powTen18("50"));
    await JLP.mint(addr3.address, powTen18("20"));

    // set up bCASH minting access
    await BCash.addMintingCaller(owner.address);
    await BCash.addMintingCaller(LPFarm.address);
    await BCash.addMintingCaller(LPFarm2.address);

    // set up NFT to allow staking
    await nft.setVE(veCash.address);

    // set up mint pass to allow burning
    await ppmp.setPapilio(nft.address);
    await nft.setPPMP(ppmp.address);

    // set up veCash necessary addresses
    await veCash.setNFT(nft.address);
    await veCash.setLPFarm1(LPFarm.address);
    await veCash.setLPFarm2(LPFarm2.address);
    await veCash.setBC(BCash.address);

    // mint bCASH to owner and stake so transfers work
    await BCash.connect(owner).mint(owner.address, 1000000);
    await BCash.connect(owner).stake();

    // mint bCASH to addresses
    await BCash.connect(owner).mint(addr1.address, 4000000);
    await BCash.connect(owner).mint(addr2.address, 70000);
    await BCash.connect(owner).mint(addr3.address, 300000);

    // set veCASH as LP address so deposits aren't taxed
    await BCash.addLP(veCash.address);

    // mint NFTs and transfer to addresses
    for (let i = 0; i < 5; i++) {
      await nft.connect(owner).mint(1);
    }
    const ownerTokens = await nft.tokensOfOwner(owner.address);
    await nft.connect(owner)["safeTransferFrom(address,address,uint256)"](owner.address, addr1.address, ownerTokens[0]);
    await nft.connect(owner)["safeTransferFrom(address,address,uint256)"](owner.address, addr1.address, ownerTokens[1]);
    await nft.connect(owner)["safeTransferFrom(address,address,uint256)"](owner.address, addr1.address, ownerTokens[2]);
    await nft.connect(owner)["safeTransferFrom(address,address,uint256)"](owner.address, addr2.address, ownerTokens[3]);
    await nft.connect(owner)["safeTransferFrom(address,address,uint256)"](owner.address, addr2.address, ownerTokens[4]);
    
    // mint PPMP to addresses
    await ppmp.connect(owner).mint([addr1.address,addr1.address,addr2.address]);
  });

  it("Check that tokens and NFTs are minted to addresses", async function () {
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
    let balance4 = await BCash.balanceOf(addr1.address);
    expect(balance4.toString().slice(0, 5)).to.equal(
      "40000"
    );
    let balance5 = await BCash.balanceOf(addr2.address);
    expect(balance5.toString().slice(0, 5)).to.equal(
      "70000"
    );
    let balance6 = await BCash.balanceOf(addr3.address);
    expect(balance6.toString().slice(0, 5)).to.equal(
      "30000"
    );
    let balance7 = await nft.balanceOf(addr1.address);
    expect(balance7).to.equal(3);
    let balance8 = await nft.balanceOf(addr2.address);
    expect(balance8).to.equal(2);
    let balance9 = await nft.balanceOf(addr3.address);
    expect(balance9).to.equal(0);

    let balance10 = await ppmp.balanceOf(addr1.address);
    expect(balance10).to.equal(2);
    let balance11 = await ppmp.balanceOf(addr2.address);
    expect(balance11).to.equal(1);
    let balance12 = await ppmp.balanceOf(addr3.address);
    expect(balance12).to.equal(0);
  });

  it("Check that LP farm adds to tier level", async function () {
    // stake
    await BCash.connect(addr1).approve(veCash.address, powTen18("4000000"));
    await veCash.connect(addr1).deposit(powTen18("1"));

    await BCash.connect(addr2).approve(veCash.address, powTen18("1"));
    await veCash.connect(addr2).deposit(powTen18("1"));

    // approve use of JLP token
    await JLP.connect(addr1).approve(LPFarm.address, powTen18("10"));
    await JLP.connect(addr2).approve(LPFarm.address, powTen18("50"));

    await LPFarm.connect(addr1).stakeLP(powTen18("5")); //should be equiv to 125k bCASH

    expect(await veCash.totalLpForUser(addr1.address)).to.equal(powTen18("125000"));

    expect(await veCash.tierFor(addr1.address)).to.equal(7);

    await LPFarm.connect(addr2).stakeLP(powTen18("1")); //should be equiv to 25k bCASH

    expect(await veCash.totalLpForUser(addr2.address)).to.equal(powTen18("25000"));

    expect(await veCash.tierFor(addr2.address)).to.equal(2);

  });

  it("Check reverts", async function () {
    const addr1Tokens = await nft.tokensOfOwner(addr1.address);
    const addr2Tokens = await nft.tokensOfOwner(addr2.address);

    await expect(
      veCash.connect(addr2).deposit(0)
    ).to.be.revertedWith("amount to deposit cannot be zero");

    // can't deposit without approval
    await expect(
      veCash.connect(addr2).deposit(powTen18("500"))
    ).to.be.revertedWith("ERC20: insufficient allowance");

    // can't withdraw 0
    await expect(
      veCash.connect(addr2).withdraw(0)
    ).to.be.revertedWith("amount to withdraw cannot be zero");

    // can't withdraw if not staked
    await expect(
      veCash.connect(addr2).withdraw(powTen18("500"))
    ).to.be.revertedWith("not enough balance");

    // can't claim if not staked
    await expect(
      veCash.connect(addr2).claim()
    ).to.be.revertedWith("user has no stake");

    // can't stake NFTs without stake
    await expect(
      veCash.connect(addr2).stakeNFTs([addr2Tokens[0]])
    ).to.be.revertedWith("You have no stake!");

    await expect(
      veCash.connect(addr2).stakeAllNFTs()
    ).to.be.revertedWith("You have no stake!");

    // can't unStake NFTs without stake
    await expect(
      veCash.connect(addr2).unStakeNFTs([addr2Tokens[0]])
    ).to.be.revertedWith("You have no stake!");

    await expect(
      veCash.connect(addr2).unStakeAllNFTs()
    ).to.be.revertedWith("You have no stake!");

    // even after staking, you can't stake or unstake someone elses NFT
    await BCash.connect(addr1).approve(veCash.address, powTen18("4000000"));
    await veCash.connect(addr1).deposit(powTen18("4000000"));

    await BCash.connect(addr2).approve(veCash.address, powTen18("1"));
    await veCash.connect(addr2).deposit(powTen18("1"));

    await veCash.connect(addr2).stakeNFTs([addr2Tokens[0]]); // stake in order to check that transfer is locked
    
    await expect(
      veCash.connect(addr2).stakeNFTs([addr1Tokens[0]])
    ).to.be.revertedWith("You don't own that Papilio!");

    await veCash.connect(addr1).unStakeNFTs([addr2Tokens[0]]); // does not revert, but won't actually unstake

    let staked = (await veCash.nftsStakedFor(addr2.address)).length;
    expect(staked).to.equal(1); // nft still staked

    // can't transfer staked nft
    await expect(
      nft.connect(addr2)["safeTransferFrom(address,address,uint256)"](addr2.address, addr3.address, addr2Tokens[0])
    ).to.be.revertedWith("Token is staked!");

    let balance = await nft.balanceOf(addr3.address);
    expect(balance).to.equal(0);

    // veCASH cannot be transferred
    await wait(5, 1); // 5 days
    await veCash.connect(addr2).claim();
    let balance2 = await veCash.balanceOf(addr2.address);
    expect(balance2.toString().slice(0, 5)).to.equal(
      "17640" //0.014 * 1.05 (nft multiplier) * 24 * 5
    );
    await expect(
      veCash.connect(addr2).transfer(addr3.address, powTen18("1"))
    ).to.be.revertedWith("No can do.");

  });

  it("Check veCASH yield and withdraws", async function () {
    const addr1Tokens = await nft.tokensOfOwner(addr1.address);
    const addr2Tokens = await nft.tokensOfOwner(addr2.address);

    await BCash.connect(addr1).approve(veCash.address, powTen18("4000000"));
    await veCash.connect(addr1).deposit(powTen18("4000000"));

    await BCash.connect(addr2).approve(veCash.address, powTen18("1"));
    await veCash.connect(addr2).deposit(powTen18("1"));

    await wait(1, 1); // 1 day
    await veCash.connect(addr2).stakeNFTs([addr2Tokens[0]]); // stake in order to check that transfer is locked
    let balance1 = await veCash.balanceOf(addr2.address);
    expect(balance1.toString().slice(0, 3)).to.equal(
      "336" // 0.014 * 24 * 1
    );

    await wait(5, 1); // 5 days
    await veCash.connect(addr2).claim();
    let balance2 = await veCash.balanceOf(addr2.address);
    expect(balance2.toString().slice(0, 5)).to.equal(
      "21000" //(0.014 * 24 * 1) + (0.014 * 1.05 (nft multiplier) * 24 * 5)
    );

    // check top tier
    await veCash.connect(addr1).claim();
    let balance3 = await veCash.balanceOf(addr1.address);
    expect(balance3.toString().slice(0, 5)).to.equal(
      "12096" //(0.014 * (1.50) (tier multiplier) * 24 * 6) * 4000000 (bCASH)
    );

    // withdrawing any amount should burn all veCASH
    await veCash.connect(addr1).withdraw(powTen18("100"));
    let balance4 = await veCash.balanceOf(addr1.address);
    expect(balance4).to.equal(0);
    
    // both stakers should still be in array
    let stakerCount = (await veCash.getStakers()).length - 1; // minus one to account for dead 0 index
    expect(stakerCount).to.equal(2); 

    // withdrawing all bCASH removes staker from array
    await veCash.connect(addr2).withdraw(powTen18("1"));
    let balance5 = await veCash.balanceOf(addr2.address);
    expect(balance5).to.equal(0);

    let stakerCount2 = (await veCash.getStakers()).length - 1; // minus one to account for dead 0 index
    expect(stakerCount2).to.equal(1); 
  });

  it("Check that tokens are assigned KindaRandom Id", async function () {
    // *NOTE* this should fail and allow you to see that tokens are being assigned randomly
    // let tokens1 = await nft.tokenMapping();
    // let nonSortedTokens = [];

    // for (let i = 0; i < 15; i++) {
    //   nonSortedTokens.push(Number(tokens1[i]));
    // }

    // let numbers1 = [];

    // for (let i = 0; i < 15; i++) {
    //   numbers1.push(Number(i));
    // }

    // expect(nonSortedTokens).to.equal(numbers1);

    for (let i = 0; i < 186; i++) {
      await nft.connect(owner).mint(1);
    }

    let tokens2 = await nft.tokenMapping();
    let sortedTokens2 = [];

    for (let i = 0; i < 202; i++) {
      sortedTokens2.push(Number(tokens2[i]));
    }

    var sortedArray: number[] = sortedTokens2.sort((n1,n2) => n1 - n2);

    let numbers2 = [];

    for (let i = 0; i < 202; i++) {
      numbers2.push(Number(i));
    }

    for (let i = 0; i < 202; i++) {
      expect(sortedArray[i]).to.equal(numbers2[i]);
    }
    
  });

  it("Check unstaking allows transfer", async function () {
    const addr1Tokens = await nft.tokensOfOwner(addr1.address);
    const addr2Tokens = await nft.tokensOfOwner(addr2.address);

    // stake
    await BCash.connect(addr1).approve(veCash.address, powTen18("4000000"));
    await veCash.connect(addr1).deposit(powTen18("4000000"));

    await BCash.connect(addr2).approve(veCash.address, powTen18("1"));
    await veCash.connect(addr2).deposit(powTen18("1"));

    await veCash.connect(addr2).stakeNFTs([addr2Tokens[0]]); // stake in order to check that transfer is locked
    await veCash.connect(addr1).stakeNFTs([addr1Tokens[0],addr1Tokens[1],addr1Tokens[2]]); // stake in order to check that transfer is locked
   
    let staked = (await veCash.nftsStakedFor(addr2.address)).length;
    expect(staked).to.equal(1); // nft still staked

    let staked1 = (await veCash.nftsStakedFor(addr1.address)).length;
    expect(staked1).to.equal(3); // nft still staked

    // can't transfer staked nft
    await expect(
      nft.connect(addr2)["safeTransferFrom(address,address,uint256)"](addr2.address, addr3.address, addr2Tokens[0])
    ).to.be.revertedWith("Token is staked!");

    await expect(
      nft.connect(addr1)["safeTransferFrom(address,address,uint256)"](addr1.address, addr3.address, addr1Tokens[2])
    ).to.be.revertedWith("Token is staked!");

    await veCash.connect(addr2).unStakeNFTs([addr2Tokens[0]]);
    await veCash.connect(addr1).unStakeAllNFTs();

    let staked3 = (await veCash.nftsStakedFor(addr2.address)).length;
    expect(staked3).to.equal(0); // no nfts staked

    let staked4 = (await veCash.nftsStakedFor(addr1.address)).length;
    expect(staked4).to.equal(0); // no nfts staked

    // transfers should now be successful
    await nft.connect(addr2)["safeTransferFrom(address,address,uint256)"](addr2.address, addr3.address, addr2Tokens[0]);
    await nft.connect(addr1)["safeTransferFrom(address,address,uint256)"](addr1.address, addr3.address, addr1Tokens[2]);  

  });

  it("Check tokenURI function and tier", async function () {
    const addr1Tokens = await nft.tokensOfOwner(addr1.address);
    const addr2TokensBefore = await nft.tokensOfOwner(addr2.address);
    await nft.connect(addr2)["safeTransferFrom(address,address,uint256)"](addr2.address, addr3.address, addr2TokensBefore[0]);
    const addr2Tokens = await nft.tokensOfOwner(addr2.address);
    const addr3Tokens = await nft.tokensOfOwner(addr3.address);
    const tokens = await nft.tokenMapping();

    //reveal
    await nft.connect(owner).reveal("ipfs://CID/");

    // stake should be max tier
    await BCash.connect(addr1).approve(veCash.address, powTen18("4000000"));
    await veCash.connect(addr1).deposit(powTen18("4000000"));

    // should be tier 1
    await BCash.connect(addr2).approve(veCash.address, powTen18("1"));
    await veCash.connect(addr2).deposit(powTen18("1"));

    let addr1Tier = await veCash.tierFor(addr1.address);
    expect(addr1Tier).to.equal(7);
    expect(await nft.tokenURI(addr1Tokens[0])).to.equal(
      `ipfs://CID/${tokens[addr1Tokens[0]]}/${addr1Tier}.json`
    )
    expect(await nft.tokenURI(addr1Tokens[1])).to.equal(
      `ipfs://CID/${tokens[addr1Tokens[1]]}/${addr1Tier}.json`
    )
    expect(await nft.tokenURI(addr1Tokens[2])).to.equal(
      `ipfs://CID/${tokens[addr1Tokens[2]]}/${addr1Tier}.json`
    )

    let addr2Tier = await veCash.tierFor(addr2.address);
    expect(addr2Tier).to.equal(1);
    expect(await nft.tokenURI(addr2Tokens[0])).to.equal(
      `ipfs://CID/${tokens[addr2Tokens[0]]}/${addr2Tier}.json`
    )

    let addr3Tier = await veCash.tierFor(addr3.address);
    expect(addr3Tier).to.equal(0);
    // address 3 is not staked, but should have an NFT tier of 1 anyways
    expect(await nft.tokenURI(addr3Tokens[0])).to.equal(
      `ipfs://CID/${tokens[addr3Tokens[0]]}/1.json`
    )

  });

  it("Check early access and PPMP burning", async function () {
    let timestamp = await JLP.time();
    //set nft start time
    await nft.connect(owner).updateStartTime(timestamp + 6000);

    // mint hasn't started, should revert
    await expect(
      nft.connect(addr3).mint(1)
    ).to.be.revertedWith("Minting has not started!");

    let timestamp2 = await JLP.time();
    //set nft start time
    await nft.connect(owner).updateStartTime(timestamp2);

    //no ppmp should fail
    await expect(
      nft.connect(addr3).mint(1, {value: ethers.utils.parseEther("5")})
    ).to.be.revertedWith("You don't have a mint pass!");

    //too many should fail
    await expect(
      nft.connect(addr1).mint(2)
    ).to.be.revertedWith("You can't mint that many!");

    //not enough value should fail
    await expect(
      nft.connect(addr1).mint(1)
    ).to.be.revertedWith("Insufficient funds!");

    let ppmpBalance1 = await ppmp.balanceOf(addr1.address);
    expect(ppmpBalance1).to.equal(2);
    //mint should burn pass
    await nft.connect(addr1).mint(1, {value: ethers.utils.parseEther("5")})
    let ppmpBalance2 = await ppmp.balanceOf(addr1.address);
    expect(ppmpBalance2).to.equal(1);

    await wait(0, 1800); // 30 minutes

    await nft.connect(addr3).mint(1, {value: ethers.utils.parseEther("5")})

    expect(await nft.balanceOf(addr3.address)).to.equal(1);

  });

});
