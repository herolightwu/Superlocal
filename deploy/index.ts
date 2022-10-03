import green from 'chalk';
import underline from 'chalk';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

/**
 * @usage yarn hardhat deploy --network rinkeby
 */
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // code here
  const [deployer] = await hre.ethers.getSigners();

  // --- ETH (testnet)
  if (['rinkeby', 'localhost'].includes(hre.network.name)) {
    console.log(`\n ${green(underline('ETH'))}`);
    // deploy Mayorship
    const mayorFactory = await hre.ethers.getContractFactory("Mayorship");
    const mayorship = await mayorFactory.deploy("");
    await mayorship.connect(deployer.address).deployed();
    console.log('Mayorship NFT : ', mayorship.address);
    // deploy Stamp
    const stampFactory = await hre.ethers.getContractFactory("StampNFT");
    const stamp = await stampFactory.deploy("");
    await stamp.connect(deployer).deployed();
    console.log('Stamp NFT : ', stamp.address);
    // deploy Local token
    const localFactory = await hre.ethers.getContractFactory("Local");
    const local = await localFactory.deploy();
    await local.connect(deployer).deployed();
    await local.connect(deployer).enableTrading();
    console.log('Local Token : ', local.address);
    // deploy Passport
    const passportFactory = await hre.ethers.getContractFactory("PassportNFT");
    const passport = await passportFactory.deploy("", stamp.address, local.address);
    // const passport = await passportFactory.deploy("", "0x49565f524b0d40114e3E6100177BBD8EdFc0e088", "0x3b096dcf4de9eafC01014d5D243802bA7E10C52A");    
    await passport.connect(deployer).deployed(); 
    console.log('Passport NFT : ', passport.address);
  }

  // --- ETH (mainnet)
  if (['eth'].includes(hre.network.name)) {
    console.log(`\n ${green(underline('ETH'))}`);

    // deploy Mayorship
    const mayorFactory = await hre.ethers.getContractFactory("Mayorship");
    const mayorship = await mayorFactory.deploy("");
    await mayorship.deployed();
    console.log('Mayorship NFT : ', mayorship.address);
    // deploy Stamp
    const stampFactory = await hre.ethers.getContractFactory("StampNFT");
    const stamp = await stampFactory.deploy("");
    await stamp.deployed();
    console.log('Stamp NFT : ', stamp.address);
    // deploy Local token
    const localFactory = await hre.ethers.getContractFactory("Local");
    const local = await localFactory.deploy();
    await local.deployed();
    await local.enableTrading();
    console.log('Local Token : ', local.address);
    // deploy Passport
    const passportFactory = await hre.ethers.getContractFactory("PassportNFT");
    const passport = await passportFactory.deploy("", stamp.address, local.address);
    await passport.deployed(); 
    console.log('Passport NFT : ', passport.address);

  }
};
export default func;