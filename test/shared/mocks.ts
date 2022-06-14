/* eslint-disable prettier/prettier */
import { MockContract } from "ethereum-waffle";
import { Signer } from "ethers";
import { formatBytes32String } from "ethers/lib/utils";
import { artifacts, waffle } from "hardhat";
import { Artifact } from "hardhat/types";
import ERC_20_ABI from "../../abis/erc20.abi.json";
import VRF_CONSUMER_BASE_ABI from "../../abis/vrfconsumerbase.json"

export async function deployMockToken(deployer: Signer): Promise<MockContract> {
  // const erc20Artifact: Artifact = await artifacts.readArtifact("ERC20");
  const erc20: MockContract = await waffle.deployMockContract(
    deployer,
    ERC_20_ABI
  );

  await erc20.mock.decimals.returns(6);
  await erc20.mock.name.returns(`USD Coin`);
  await erc20.mock.symbol.returns(`USDC`);
  await erc20.mock.transferFrom.returns(true);

  return erc20;
}

export async function deployMockVFRConsumerBase(deployer: Signer): Promise<MockContract> {
  // const erc20Artifact: Artifact = await artifacts.readArtifact("ERC20");
  const VRFConsumerBase: MockContract = await waffle.deployMockContract(
    deployer,
    VRF_CONSUMER_BASE_ABI
  );

  await VRFConsumerBase.mock.requestRandomness.returns(formatBytes32String("1234"))

  return VRFConsumerBase;
}
