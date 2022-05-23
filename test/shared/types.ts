import { Fixture, MockContract } from "ethereum-waffle";
import { Wallet } from "@ethersproject/wallet";
import { CoinFlip } from "../../typechain";

declare module "mocha" {
  export interface Context {
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
    mocks: Mocks;
    lending: CoinFlip;
  }
}

export interface Signers {
  deployer: Wallet;
  alice: Wallet;
  bob: Wallet;
}

export interface Mocks {
  mockERC20: MockContract;
}
