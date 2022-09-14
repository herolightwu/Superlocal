import { expect } from "chai";
import { utils } from 'ethers';
import { ethers, waffle } from "hardhat";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

describe("StampNFT", function () {
    let owner!: SignerWithAddress;
    let holder!: SignerWithAddress;
    let externalUser!: SignerWithAddress;
    let contract!: any;

    before(async function () {
        [owner, holder, externalUser] = await ethers.getSigners();
    }); 

    it('Contract deployment', async function () {
      const contractFactory = await ethers.getContractFactory("StampNFT");
      contract = await contractFactory.deploy("");

      await contract.connect(owner.address).deployed();
    }); 

    it('deploys with the correct owner', async function () {
      expect(await contract.owner()).to.equal(owner.address);
    });

    it('Check initial data', async function () {
      expect(await contract.name()).to.equal("StampNFT");
      expect(await contract.symbol()).to.equal("STAMPNFT");
    }); 

    it('Mint and check level', async function () {
      await expect(contract.connect(holder).mint({ value: utils.parseUnits('1', 14) })).to.be.revertedWith('Not enough ether to purchase NFTs.');
      await expect(contract.connect(holder).mint({ value: utils.parseUnits('1', 16) })).to.be.emit(contract, 'Mint');
      await expect(contract.connect(externalUser).mint({ value: utils.parseUnits('1', 14) })).to.be.revertedWith('Not enough ether to purchase NFTs.');
      await expect(contract.connect(externalUser).mint({ value: utils.parseUnits('1', 16) })).to.be.emit(contract, 'Mint');
      await expect(contract.connect(owner).reserveMint()).to.be.emit(contract, 'Mint');
      await expect(contract.connect(owner).reserveMint()).to.be.emit(contract, 'Mint');

      let level = await contract.getStampLevel(0);
      console.log ("stamp 0 level : ", level);
      level = await contract.getStampLevel(1);
      console.log ("stamp 1 level : ", level);
      level = await contract.getStampLevel(2);
      console.log ("stamp 2 level : ", level);
    });

    it('Check balance and token IDs', async function () {

       // Check balances
      expect(await contract.balanceOf(await owner.getAddress())).to.equal(2);
      expect(await contract.balanceOf(await externalUser.getAddress())).to.equal(1);
      expect(await contract.balanceOf(await holder.getAddress())).to.equal(1);

      // check token IDs
      let expect_num_0 = utils.parseUnits('0', 1);
      let IDs = await contract.tokensOfOwner(holder.address);
      expect(IDs[0]).to.equal(expect_num_0);
      // externaluser
      IDs = await contract.tokensOfOwner(externalUser.address);
      expect(IDs[0]).to.equal(utils.parseUnits('1', 0));
      // owner
      IDs = await contract.tokensOfOwner(owner.address);
      expect(IDs[0]).to.equal(utils.parseUnits('2', 0));
      expect(IDs[1]).to.equal(utils.parseUnits('3', 0));

    }); 

    it('Set external image url', async function () {

      const image = "https://www.engadget.com/ap-nft-marketplace-photojournalism-134011058.html";

      await expect(contract.connect(holder).setStampImage(0, image)).to.be.revertedWith('Ownable: caller is not the owner');

      await contract.connect(owner).setStampImage(0, image);
      expect(await contract.getStampImage(0)).to.equal(image);      

   }); 

   it('Withdraw', async function () {
      // will be 0.02 ethers after mint 2 Stamp NFT
      let balance = await ethers.provider.getBalance(contract.address);
      expect(balance).to.equal(utils.parseUnits('2', 16));
      // will be 0 ethers after withdraw
      await contract.connect(owner).withdraw();
      balance = await ethers.provider.getBalance(contract.address);
      expect(balance).to.equal(utils.parseUnits('0', 16));
  }); 
})