import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers, upgrades } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { NULL_ADDR } from "../utils";

describe("Edge cases on the ANTG", function () {
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

  it("Access related", async function () {
    await AntG.connect(owner).airdrop(
      [addr1.address, addr2.address],
      ethers.utils.parseEther("1.2")
    );
    await expect(
      AntG.connect(addr1).airdrop(
        [addr1.address, addr2.address],
        ethers.utils.parseEther("100")
      )
    ).to.be.reverted;
    await expect(AntG.burn(addr1.address, ethers.utils.parseEther("1.2"))).to.be
      .reverted;
    await expect(AntG.connect(addr1.address).setSugaAddress(NULL_ADDR)).to.be
      .reverted;
    await AntG.connect(owner).setSugaAddress(addr1.address);
    await AntG.connect(addr1).burn(
      addr1.address,
      ethers.utils.parseEther("1.2")
    );
    await AntG.connect(owner).setSugaAddress(addr2.address);
    await expect(
      AntG.connect(addr1).burn(addr1.address, ethers.utils.parseEther("1.2"))
    ).to.be.reverted;
  });

  it("Airdrop users", async function () {
    await AntG.connect(owner).airdrop(
      [addr1.address, addr2.address],
      ethers.utils.parseEther("100")
    );
    await AntG.connect(owner).airdrop(
      [addr1.address, addr3.address],
      ethers.utils.parseEther("100")
    );
    expect(
      ethers.utils.formatEther(await AntG.balanceOf(addr1.address)).slice(0, 4)
    ).to.equal("200.");
    expect(
      ethers.utils.formatEther(await AntG.balanceOf(addr2.address)).slice(0, 4)
    ).to.equal("100.");
    expect(
      ethers.utils.formatEther(await AntG.balanceOf(addr3.address)).slice(0, 4)
    ).to.equal("100.");
  });
});
