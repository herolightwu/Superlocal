import { expect, util } from "chai";
import { BigNumber, utils } from 'ethers';
import { ethers } from "hardhat";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

describe("Mayorship", function () {
    let owner!: SignerWithAddress;
    let holder!: SignerWithAddress;
    let externalUser!: SignerWithAddress;
    let contract!: any;

    before(async function () {
        [owner, holder, externalUser] = await ethers.getSigners();
    }); 

    it('Contract deployment', async function () {
        const contractFactory = await ethers.getContractFactory("Mayorship");
        contract = await contractFactory.deploy("");
  
        await contract.connect(owner.address).deployed();      
    }); 

    it('deploys with the correct owner', async function () {
        expect(await contract.owner()).to.equal(owner.address);
    });

    it('Check initial data', async function () {
        expect(await contract.name()).to.equal("Mayorship");
        expect(await contract.symbol()).to.equal("MAYORSHIP");
    }); 

    describe("Mint NFTs and Withdraw", function () {
        it('Mint NFTs', async function () {
            // Place id = 1
            await expect(contract.connect(holder).mint(1, { value: utils.parseUnits('7', 14) })).to.be.revertedWith('Not enough ether to purchase NFTs.');
            await expect(contract.connect(holder).mint(1, { value: utils.parseUnits('7', 16) })).to.be.emit(contract, 'Mint');
            await expect(contract.connect(externalUser).mint(2, { value: utils.parseUnits('7', 16) })).to.be.emit(contract, 'Mint');
        });
    
        it('Owner Mint NFTs', async function () {
            //place id = 2
            await expect(contract.connect(owner).reserveMint(3)).to.be.emit(contract, 'Mint');
        });

        it('Can not mint with same place id', async function () {
            await expect(contract.connect(holder).mint(1, { value: utils.parseUnits('7', 16) })).to.be.revertedWith('The place was occupied already!');
            await expect(contract.connect(owner).reserveMint(2)).to.be.revertedWith('The place was occupied already!');
        });

        it('Withdraw', async function () {
            // will be 0.07 ethers after mint 2 Mayorship NFT
            let balance = await ethers.provider.getBalance(contract.address);
            expect(balance).to.equal(utils.parseUnits('14', 16));
            // will be 0 ethers after withdraw
            await contract.connect(owner).withdraw();
            balance = await ethers.provider.getBalance(contract.address);
            expect(balance).to.equal(utils.parseUnits('0', 16));
          }); 
    })    

    describe('Check place ID and token ID', function () {
        it('tokenId 0 was mint for place id 1 by holder', async function () {
            expect(await contract.getTokenIdByPlace(1)).to.equal(0);
        });

        it('tokenId 1 was mint for place id 2 by owner', async function () {
            expect(await contract.getTokenIdByPlace(2)).to.equal(1);
        });

        it('place id 1 was occupied for tokenId 0 by holder', async function () {
            expect(await contract.getPlaceIdByToken(0)).to.equal(1);
        });

        it('place id 3 was occupied for tokenId 2 by owner', async function () {
            expect(await contract.getPlaceIdByToken(2)).to.equal(3);
        });
      
    })
})