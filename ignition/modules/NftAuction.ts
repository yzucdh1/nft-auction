import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("NftAuctionModule", (m) => {
  const nft = m.contract("NftToken");
  return { nft };
});