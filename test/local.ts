import { expect, util } from "chai";
import { BigNumber, utils } from 'ethers';
import { ethers, waffle} from "hardhat";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

describe("LOLCAL Token", function () {
    let owner!: SignerWithAddress;
    let holder!: SignerWithAddress;
    let externalUser!: SignerWithAddress;
    let local!:any;
    let total:any;

    before(async function () {
      [owner, holder, externalUser] = await ethers.getSigners();
      
      const contractFactory = await ethers.getContractFactory("Local");
      local = await contractFactory.deploy();
      await local.connect(owner).deployed();
      await local.connect(owner).enableTrading();
    }); 

    it('deploys with the correct owner', async function () {
        expect(await local.owner()).to.equal(owner.address);
    });

    it('has an intial totalSupply() of zero', async function () {
    expect(await local.totalSupply()).to.equal(utils.parseUnits('0', 1));
    expect(await local.balanceOf(holder.address)).to.equal(utils.parseUnits('0', 1));
    });

    describe('check properties of token', () =>{
        it('Check name and symbol', async function () {
            expect(await local.name()).to.equal("Local");
            expect(await local.symbol()).to.equal("LOCAL");
            expect(await local.decimals()).to.equal(9);
        }); 

        it('check set/get the properties', async function () {
            // check TaxFee
            expect(await local.getTaxFeePercent()).to.equal(5);
            await expect(local.connect(owner).setTaxFeePercent(utils.parseUnits('7', 0))).to.be.emit(local, 'TaxFeePercentUpdated');
            expect(await local.getTaxFeePercent()).to.equal(7);
            // check RoyaltyFee
            expect(await local.getRoyaltyFeePercent()).to.equal(5);
            await expect(local.connect(owner).setRoyaltyFeePercent(utils.parseUnits('7', 0))).to.be.emit(local, 'RoyaltyFeePercentUpdated');
            expect(await local.getRoyaltyFeePercent()).to.equal(7);

            // check MaxTxAmount
            expect(await local.getMaxTxAmount()).to.equal(utils.parseUnits('200', 9));
            await expect(local.connect(owner).setMaxTxAmount(utils.parseUnits('250', 9))).to.be.emit(local, 'MaxTxAmountUpdated');
            expect(await local.getMaxTxAmount()).to.equal(utils.parseUnits('250', 9));
        });
    });

    describe('Mint ', () => {
        it('mints tokens', async function () {
          // mint 200 INTI to holder
          const amount = utils.parseUnits('200', 9);
          const overAmount = utils.parseUnits('300', 9);
          await expect(local.connect(holder).mint(amount, { value: utils.parseUnits('200', 13) })).to.be.revertedWith('Not enough ether to mint tokens');
          await expect(local.connect(holder).mint(overAmount, { value: utils.parseUnits('300', 14) })).to.be.revertedWith('One mint amount exceeds the maxTxAmount');
          await expect(local.connect(holder).mint(amount, { value: utils.parseUnits('200', 14) })).to.be.emit(local, 'Mint');
          expect(await local.balanceOf(holder.address)).to.equal(amount);
          
          // mint 100 INTI to externalUser
          const ex_amount = utils.parseUnits('100', 9);
          await expect(local.connect(externalUser).mint(ex_amount, { value: utils.parseUnits('100', 14) })).to.be.emit(local, 'Mint');
          expect(await local.balanceOf(externalUser.address)).to.equal(ex_amount);
        });

        it('mints tokens for rewards', async function () {
            // mint 100 INTI to holer from owner
            const amount = utils.parseUnits('100', 9);
            const overAmount = utils.parseUnits('300', 9);
            await expect(local.connect(owner).rewardMint(holder.address, overAmount)).to.be.revertedWith('One mint amount exceeds the maxTxAmount');
            await expect(local.connect(owner).rewardMint(holder.address, amount)).to.be.emit(local, 'RewardMint');
            expect(await local.balanceOf(holder.address)).to.equal(utils.parseUnits('300', 9));
            
        });
    
        it('increments totalSupply() as expected', async () => {
            total = await local.totalSupply();
            expect(total).to.equal(utils.parseUnits('400', 9));
        });
        
    });

    describe('Transfer And Reflection', () => {
        it('transfers work correctly when reflections are disabled', async function () {
            // MW ----- excluded fee mode -------------
            await local.connect(owner).excludeFromFee(holder.address);
            await local.connect(owner).excludeFromFee(externalUser.address);
      
            const first_holder_bal = await local.balanceOf(holder.address);
            const txn2 = utils.parseUnits('50', 9);
            await local.connect(holder).transfer(externalUser.address, txn2);
      
            const holder_bal = await local.balanceOf(holder.address);
            const external_bal = await local.balanceOf(externalUser.address);
            expect(holder_bal.toNumber() + txn2.toNumber()).to.equal(first_holder_bal);
            expect(holder_bal.toNumber() + external_bal.toNumber()).to.equal(total);
          });

          it('no fees are collected when reflections are disabled', async function () {

            const before_bal = await local.balanceOf(local.address);
            const txn2 = utils.parseUnits('50', 9);
            await local.connect(holder).transfer(externalUser.address, txn2);
            const after_bal = await local.balanceOf(local.address);
            
            expect(before_bal).to.equal(after_bal);
          });

          it('reflection when holder transfer to external user', async function () {
            // MW ----- include fee mode -------------
            await local.connect(owner).includeInFee(holder.address);
            await local.connect(owner).includeInFee(externalUser.address);
            //set the default fee
            await expect(local.connect(owner).setTaxFeePercent(utils.parseUnits('5', 0))).to.be.emit(local, 'TaxFeePercentUpdated');
            await expect(local.connect(owner).setRoyaltyFeePercent(utils.parseUnits('5', 0))).to.be.emit(local, 'RoyaltyFeePercentUpdated');
          // --- starting balance
            const startBalance = utils.parseUnits('200', 9);
            expect(await local.balanceOf(holder.address)).to.equal(startBalance);

            // --- [txn1] send to externalUser
            const txn = utils.parseUnits('100', 9);
            await local.connect(holder).transfer(externalUser.address, txn);

            const newBalance = await local.balanceOf(holder.address);
            console.log("Holder balance after transfer : ", newBalance.toString());

            const exBalance = await local.balanceOf(externalUser.address);
            console.log("External User balance after transfer : ", exBalance.toString());

            // TaxFee = 5 %, RoyaltyFee = 5 %
            const txFee = txn.toNumber() * 5 / 100; 
            const royalFee = txn.toNumber() * 5 / 100;
            const transAmount = txn.toNumber() - txFee - royalFee;
            // holder's balance after transfer
            const after_bal = startBalance.toNumber() - txn.toNumber();
            // holder should get the rewards from transfer and this balance is new balance
            const reward_bal = Math.floor(after_bal * Math.floor(total.toNumber() * Math.pow(10, 11)/(total.toNumber() - txFee)) / Math.pow(10, 11));
            expect(newBalance).to.equal(reward_bal);

            // for externalUser
            const after_ex_bal = startBalance.toNumber() + transAmount;
            // externalUser should get the rewards from transfer and this balance is exBalance
            const reward_ex_bal = Math.floor(after_ex_bal * Math.floor(total.toNumber() * Math.pow(10, 12)/(total.toNumber() - txFee)) / Math.pow(10, 12));
            expect(exBalance).to.equal(reward_ex_bal);


            const fee_bal = await local.balanceOf(local.address);
            console.log("Collected Fee : ", fee_bal.toString());

            total = await local.totalSupply();
            console.log("Total : ", total.toString());
        });
          
    });

})