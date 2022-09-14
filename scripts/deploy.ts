import yellow from 'chalk';
import underline from 'chalk';
import { ethers } from "hardhat";

/**
 * @usage yarn hardhat node
 * @usage yarn hardhat run --network localhost scripts/deploy.ts
 */
 async function main() {
  const [deployer] = await ethers.getSigners();

  // --- BSC
  console.log(`\n ${yellow(underline('ETH'))}`);
    // deploy Mayorship
    const mayorFactory = await ethers.getContractFactory("Mayorship");
    const mayorship = await mayorFactory.deploy("");
    await mayorship.connect(deployer.address).deployed();
    console.log('Mayorship NFT : ', mayorship.address);
    // deploy Stamp    
    const stampFactory = await ethers.getContractFactory("StampNFT");
    const stamp = await stampFactory.deploy("");
    await stamp.connect(deployer).deployed();
    console.log('Stamp NFT : ', stamp.address);
    // deploy Local token
    const localFactory = await ethers.getContractFactory("Local");
    const local = await localFactory.deploy();
    await local.connect(deployer).deployed();
    await local.connect(deployer).enableTrading();
    console.log('Local Token : ', local.address);
    // deploy Passport
    const passportFactory = await ethers.getContractFactory("PassportNFT");
    const passport = await passportFactory.deploy("", stamp.address, local.address);
    await passport.connect(deployer).deployed(); 
    console.log('Passport NFT : ', passport.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
