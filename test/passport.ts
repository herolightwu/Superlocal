import { expect, util } from "chai";
import { BigNumber, utils } from 'ethers';
import { ethers, waffle} from "hardhat";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { MockContract } from 'ethereum-waffle';

import MockRandomABI from '../artifacts/contracts/Randomness.sol/Randomness.json';
import hre from 'hardhat';

const { deployMockContract } = waffle;
const TIME_TEN_DAYS = 10 * 24 * 3600;
const TIME_ONE_DAYS = 1 * 24 * 3600;

describe("PassportNFT", function () {
    let owner!: SignerWithAddress;
    let holder!: SignerWithAddress;
    let externalUser!: SignerWithAddress;
    let local!:any;
    let passport!: any;
    let stamp!: any;
    let mockRandom: MockContract;

    before(async function () {
        [owner, holder, externalUser] = await ethers.getSigners();
    }); 

    it('Contract deployment', async function () {
        const localFactory = await ethers.getContractFactory("Local");
        local = await localFactory.deploy();
        await local.connect(owner).deployed();
        await local.connect(owner).enableTrading();

        mockRandom = await deployMockContract(owner, MockRandomABI.abi);

        const stampFactory = await ethers.getContractFactory("StampNFT");
        stamp = await stampFactory.deploy(
            "", mockRandom.address
        );

        await stamp.connect(owner.address).deployed();

        const passportFactory = await ethers.getContractFactory("PassportNFT");
        passport = await passportFactory.deploy("", stamp.address, local.address);
  
        await passport.connect(owner.address).deployed(); 
    }); 

    it('deploys with the correct owner', async function () {
        expect(await passport.owner()).to.equal(owner.address);
    });

    it('Check initial data', async function () {
        expect(await passport.name()).to.equal("PassportNFT");
        expect(await passport.symbol()).to.equal("PASSPORTNFT");
    }); 

    it('Mint the Passport and Stamp', async function () {
        //Mint Stamp
        await mockRandom.mock.getRandom.returns(5);
        await expect(stamp.connect(holder).mint({ value: utils.parseUnits('1', 14) })).to.be.revertedWith('Not enough ether to purchase NFTs.');
        await expect(stamp.connect(holder).mint({ value: utils.parseUnits('1', 16) })).to.be.emit(stamp, 'Mint');
        await mockRandom.mock.getRandom.returns(3);
        await expect(stamp.connect(externalUser).mint({ value: utils.parseUnits('1', 14) })).to.be.revertedWith('Not enough ether to purchase NFTs.');
        await expect(stamp.connect(externalUser).mint({ value: utils.parseUnits('1', 16) })).to.be.emit(stamp, 'Mint');
        
        //Mint Passport
        await expect(passport.connect(holder).mint({ value: utils.parseUnits('1', 14) })).to.be.revertedWith('Not enough ether to purchase NFTs.');
        await expect(passport.connect(holder).mint({ value: utils.parseUnits('25', 15) })).to.be.emit(passport, 'Mint');
        await expect(passport.connect(externalUser).mint({ value: utils.parseUnits('1', 14) })).to.be.revertedWith('Not enough ether to purchase NFTs.');
        await expect(passport.connect(externalUser).mint({ value: utils.parseUnits('25', 15) })).to.be.emit(passport, 'Mint');

        await expect(passport.connect(owner).reserveMint()).to.be.emit(passport, 'Mint');
    });

    it('Check addresses by Stamp and Passport id', async function () {
        // check address of stamp holder by Stamp id
        expect(await stamp.ownerOf(0)).to.equal(holder.address);
        expect(await stamp.ownerOf(1)).to.equal(externalUser.address);
        // check address of passport holder by pasport id
        expect(await passport.ownerOf(0)).to.equal(holder.address);
        expect(await passport.ownerOf(1)).to.equal(externalUser.address);
        expect(await passport.ownerOf(2)).to.equal(owner.address);      
    }); 

    it('Apply Stamp to Passport', async function () {
        await expect(passport.connect(owner).setStamp(0, 3)).to.be.revertedWith("ERC721: invalid token ID");
        await expect(passport.connect(owner).setStamp(0, 1)).to.be.revertedWith("Passport and Stamp has difference holders");
        await expect(passport.connect(owner).setStamp(0, 0)).to.be.emit(passport, "StampApplied");
        await expect(passport.connect(owner).setStamp(1, 1)).to.be.emit(passport, "StampApplied");            
    }); 
    
    it('Check level functions', async function () {
        // level up to 1 level
        expect(await passport.getPassportLevel(0)).to.equal(0);
        expect(await passport.getAppliedStampCount(0)).to.equal(1);
        await expect(passport.connect(holder).levelUpPassport(0, {value : utils.parseUnits('0', 14)})).to.be.revertedWith("Not enough tokens to level up passport");
        // mint local token to levelup the passport of holder
        const amount = utils.parseUnits('200', 9);
        expect(await local.connect(holder).mint(amount, { value: utils.parseUnits('200', 14) })).to.be.emit(local, 'Mint');
        expect(await local.balanceOf(holder.address)).to.equal(amount);
        await local.connect(holder).approve(passport.address, amount);
        // level up
        expect(await passport.connect(holder).levelUpPassport(0, {value : utils.parseUnits('0', 14)})).to.be.emit(passport, 'LevelUpPassport');
        expect(await passport.getPassportLevel(0)).to.equal(1);
        await expect(passport.connect(holder).levelUpPassport(0, {value : utils.parseUnits('25', 15)})).to.be.revertedWith('Applied stamps does not enough');
        // mint stamp
        await expect(stamp.connect(holder).mint({ value: utils.parseUnits('1', 16) })).to.be.emit(stamp, 'Mint');
        
        await expect(passport.connect(owner).setStamp(0, 2)).to.be.emit(passport, "StampApplied");
        expect(await passport.getAppliedStampCount(0)).to.equal(2);
        // level up to 2 level
        await expect(passport.connect(holder).levelUpPassport(0, {value : utils.parseUnits('1', 15)})).to.be.revertedWith('Not enough ether to level up passport');
        await expect(passport.connect(externalUser).levelUpPassport(0, {value : utils.parseUnits('25', 15)})).to.be.revertedWith('Holder only can level up');
        await expect(passport.connect(holder).levelUpPassport(0, {value : utils.parseUnits('25', 15)})).to.be.emit(passport, 'LevelUpPassport');
        expect(await passport.getPassportLevel(0)).to.equal(2);
        
    });

    it('Check luck functions',async function () {
      await passport.connect(owner).setPassportLuck(0, 50);
      expect(await passport.getPassportLuck(0)).to.equal(50); 
    });

    it('Check renewal functions', async function () {
      let latestBlock = await hre.ethers.provider.getBlock("latest");

    //   console.log("current time: ", latestBlock.timestamp);
      
      // set Renewal
      await hre.ethers.provider.send("evm_increaseTime", [TIME_TEN_DAYS]);
      await hre.ethers.provider.send("evm_mine", []);
      await expect(passport.getPassportDecay(0)).to.be.revertedWith('Passport expired');

      latestBlock = await hre.ethers.provider.getBlock("latest");
    //   console.log("Next time: ", latestBlock.timestamp);
      await expect(passport.connect(owner).setPassportRenwal(0, latestBlock.timestamp)).to.be.revertedWith('Renewal date is past');
      await expect(passport.connect(owner).setPassportRenwal(0, latestBlock.timestamp + TIME_TEN_DAYS)).to.be.emit(passport, 'SetPassportRenewal');
      expect(await passport.getPassportDecay(0)).to.equal(10);

    });

    it('Check image functions', async function () {
        // set, get image
      const image = "https://www.engadget.com/ap-nft-marketplace-photojournalism-134011058.html";

      await expect(passport.connect(holder).setPassportImage(0, image)).to.be.revertedWith('Ownable: caller is not the owner');

      await passport.connect(owner).setPassportImage(0, image);
      expect(await passport.getPassportImage(0)).to.equal(image); 
      
    });

    it('Check Stamp functions : Get the stamp from Passport',async function () {
        let applied_stamps = await passport.getPassportStamps(0);
        expect(applied_stamps[0]).to.equal(0);

        expect(await passport.getAppliedStampCount(0)).to.equal(2);
    });

    it('Check Stamp functions : check maxApplyStamp',async function () {
        expect(await passport.getMaxApplyStamp()).to.equal(20);

        expect(await passport.connect(owner).setMaxApplyStamp(25)).to.be.emit(passport, 'MaxApplyStampUpdated');
        expect(await passport.getMaxApplyStamp()).to.equal(25);
    });

    it('Withdraw', async function () {
        // will be 0.05 ethers after mint 2 Passport NFT
      let balance = await ethers.provider.getBalance(passport.address);
      expect(balance).to.equal(utils.parseUnits('75', 15));
      // will be 0 ethers after withdraw
      await passport.connect(owner).withdraw();
      balance = await ethers.provider.getBalance(passport.address);
      expect(balance).to.equal(utils.parseUnits('0', 16));
      
    }); 
    
})