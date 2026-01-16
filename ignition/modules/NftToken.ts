import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("NftTokenModule", (m) => {
  const nft = m.contract("NftToken");
  return { nft };
});