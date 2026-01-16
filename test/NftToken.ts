import { expect } from "chai";
import { network } from "hardhat";

// 连接网络
const { ethers, networkHelpers } = await network.connect();

async function deployNftTokenFixture() {
  const nft = await ethers.deployContract("NftToken");
  return { nft };
}

describe("NftToken", function () {
  describe("Deployment", async function () {
    it("should have a valid address", async function () {
      const { nft } = await networkHelpers.loadFixture(deployNftTokenFixture);
      const addr = await nft.getAddress();

      expect(addr).to.be.a("string");
      expect(addr).to.be.length(42);
      expect(addr).to.be.match(/^0x[a-fA-F0-9]{40}$/);
    });
  });
});