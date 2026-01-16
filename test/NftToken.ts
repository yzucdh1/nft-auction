import { expect } from "chai";
import { network } from "hardhat";

// 连接网络
const { ethers, networkHelpers } = await network.connect();

let _tokenURI = "https://example.com/nft/1";
let _mintPrice = ethers.parseEther("0.01");

async function deployNftTokenFixture() {
    const [owner] = await ethers.getSigners();
    const nftToken = await ethers.deployContract("NftToken");
    return { nftToken, owner };
}

describe("NftToken", function () {
    describe("Deployment", function () {
        it("Should deploy the contract successfully", async function () {
            const { nftToken } = await networkHelpers.loadFixture(deployNftTokenFixture);
            expect(nftToken.target).to.properAddress;
        });
    });

    describe("Minting", function () {
        it("Should mint a new NFT", async function () {
            const { nftToken, owner } = await networkHelpers.loadFixture(deployNftTokenFixture);
            const mintTx = await nftToken.mint(_tokenURI, { value: _mintPrice });
            await mintTx.wait();

            const tokenId = await nftToken._tokenIdCount();
            expect(tokenId).to.equal(1);

            const ownerOfToken = await nftToken.ownerOf(tokenId);
            expect(ownerOfToken).to.equal(owner.address);

            const tokenURI = await nftToken.tokenURI(tokenId);
            expect(tokenURI).to.equal(_tokenURI);
        });

        it ("Should emit Mint event on successful mint", async function () {
            const { nftToken, owner } = await networkHelpers.loadFixture(deployNftTokenFixture);
            const mintTx = await nftToken.mint(_tokenURI, { value: _mintPrice });
            await mintTx.wait();

            const tokenId = await nftToken._tokenIdCount();
            const tokenURI = await nftToken.tokenURI(tokenId);
            expect(mintTx).to.emit(nftToken, "Mint").withArgs(owner.address, tokenId, tokenURI);
        });

        it("Should fail if insufficient Ether is sent", async function () {
            const { nftToken } = await networkHelpers.loadFixture(deployNftTokenFixture);
            await expect(
                nftToken.mint(_tokenURI, { value: ethers.parseEther("0.005") })
            ).to.be.revertedWith("Insufficient payment");
        });

        it("Should fail if max supply is exceeded", async function () {
            const { nftToken } = await networkHelpers.loadFixture(deployNftTokenFixture);
            for (let i = 0; i < 10000; i++) {
                const mintTx = await nftToken.mint(_tokenURI, { value: _mintPrice });
                await mintTx.wait();
            }
            await expect(
                nftToken.mint(_tokenURI, { value: _mintPrice })
            ).to.be.revertedWith("Max supply reached");
        });

        it("Should support ERC2981 interface", async function () {
            const { nftToken } = await networkHelpers.loadFixture(deployNftTokenFixture);
            const ERC2981InterfaceId = "0x2a55205a";
            expect(await nftToken.supportsInterface(ERC2981InterfaceId)).to.equal(true);
        });
    });
});