/* eslint-disable prettier/prettier */
import { Fixture, MockContract } from "ethereum-waffle";
import { ContractFactory, Wallet } from "ethers";
import { ethers } from "hardhat";
import { CoinFlip } from "../../typechain";
import { deployMockToken } from "./mocks";

type unitCoinflipFixture = {
  coinflip: CoinFlip;
  mockERC20: MockContract;
};

export const unitCoinflipFixture: Fixture<unitCoinflipFixture> = async (
  signers: Wallet[]
) => {
  const deployer: Wallet = signers[0];

  const lendingFactory: ContractFactory = await ethers.getContractFactory(
    `CoinFlip`
  );

  const coinflip: CoinFlip = (await lendingFactory
    .connect(deployer)
    .deploy()) as CoinFlip;

  await coinflip.deployed();

  const mockERC20 = await deployMockToken(deployer);

  return { coinflip, mockERC20 };
};
