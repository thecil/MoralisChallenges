/* eslint-disable prettier/prettier */
import { Wallet } from 'ethers';
import { parseEther, formatEther } from 'ethers/lib/utils';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { assert } from 'console';
import { deployMockToken } from '../../shared/mocks';

export const shouldDepositERC20 = (): void => {

    context(`#deposit`, async function () {

        it(`should not be able to deposit as non admin`, async function () {
            const amount: BigNumber = parseEther(`1`);

            await expect(
                this.coinflip
                    .connect(this.signers.alice)
                    .deposit(
                        { value: amount })
            ).to.be.revertedWith("Caller is not owner")

            await expect(
                this.coinflip
                    .connect(this.signers.bob)
                    .deposit(
                        { value: amount })
            ).to.be.revertedWith("Caller is not owner")    
      });

      it(`owner should not be able to deposit funds <= 0`, async function () {
            const amount: BigNumber = parseEther(`0`);

            await expect(
                this.coinflip
                    .connect(this.signers.deployer)
                    .deposit(
                        { value: amount})
            ).to.be.reverted  
      });

        it(`owners contract balances should update correctly after deposit funds`, async function () {
            // let balance = await this.signers.alice.getBalance()
            // const formatedBalance = formatEther(balance.toString())
            const amount: BigNumber = parseEther(`1`);
    
            const BalanceBefore = await this.coinflip.getPlayerBalance("ETH")

            await this.coinflip
                .connect(this.signers.deployer)
                .deposit(
                    { value: amount})
            
            const BalanceAfter = await this.coinflip.getPlayerBalance("ETH")
                // console.log('balances', BalanceAfter.toBigInt(), BalanceBefore.add(amount).toBigInt(), amount, typeof(BalanceAfter), typeof(BalanceBefore))
            assert(
                BalanceAfter.toBigInt() ===
                BalanceBefore.add(amount).toBigInt(), 
                "balances do not equal"
            );    
        });

        it(`deposit event should be emitted`, async function () {

            const amount: BigNumber = parseEther(`1`);

            await expect(this.coinflip
                .connect(this.signers.deployer)
                .deposit(
                    { value: amount})
            ).to.emit(this.coinflip, `DepositMade`) 
        });

        it(`owners  wallet balances should update correctly after deposit funds`, async function () {
            const balanceBefore: BigNumber = await this.signers.alice.getBalance()
            // const formatedBalanceBefore = formatEther(balanceBefore)
            const amount: BigNumber = parseEther(`1`);
    
            await this.coinflip
                .connect(this.signers.deployer)
                .deposit(
                    { value: amount})
            
            const balanceAfter: BigNumber = await this.signers.alice.getBalance()
            // const formatedBalanceAfter = formatEther(balanceAfter)
            // console.log('wallet balances', formatedBalanceAfter, formatedBalanceBefore, typeof(formatedBalanceAfter), typeof(formatedBalanceBefore))
            assert(
                balanceAfter.toBigInt() === 
                balanceBefore.add(amount).toBigInt(), 
                "wallet balances do not equal"
            ); 
        });

    });
  };
  