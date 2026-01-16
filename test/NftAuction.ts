import { expect } from "chai";
import { network } from "hardhat";

// 连接网络
const { ethers, networkHelpers } = await network.connect();

async function deployNftAuctionFixture() {
  const nftAuction = await ethers.deployContract("NftAuction");

  return { nftAuction };
}

describe("NftAuction", function () {
  describe("Deployment", function () {
    it("Should deploy the contract successfully", async function () {
      const { nftAuction } = await networkHelpers.loadFixture(deployNftAuctionFixture);
      expect(nftAuction.target).to.properAddress;
    });
  });
});