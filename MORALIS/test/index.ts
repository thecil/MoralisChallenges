import { waffle } from "hardhat";
import { Mocks, Signers } from "./shared/types";
//import { shouldDeposit } from "./Lending/LendingShouldDeposit.spec";
import { shouldDeposit } from "./unitTests/Deposit/DepositTest";
import { shouldDepositERC20 } from "./unitTests/Deposit/DepositERC20Test";
import { shouldWithdraw } from "./unitTests/Withdraw/WithdrawTest";
import { unitCoinflipFixture } from './shared/fixtures';

describe(`Unit tests`, async () => {
  before(async function () {
    const wallets = waffle.provider.getWallets();

    this.signers = {} as Signers;
    this.signers.deployer = wallets[0];
    this.signers.alice = wallets[1];
    this.signers.bob = wallets[2];

    this.loadFixture = waffle.createFixtureLoader(wallets);
  });

  describe(`Deposit`, async () => {
    beforeEach(async function () {
      const { coinflip, mockERC20 } = await this.loadFixture(unitCoinflipFixture);

      this.coinflip = coinflip;

      this.mocks = {} as Mocks;
      this.mocks.mockERC20 = mockERC20;
    });

    shouldDeposit();
    shouldDepositERC20()
    shouldWithdraw()
  });
});
