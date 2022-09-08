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
    const randomFactory = await hre.ethers.getContractFactory("Randomness");
    const randomless = await randomFactory.deploy();
    await randomless.connect(deployer.address).deployed();

    const stampFactory = await hre.ethers.getContractFactory("StampNFT");
    const stamp = await stampFactory.deploy("", randomless.address);
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
    const randomFactory = await hre.ethers.getContractFactory("Randomness");
    const randomless = await randomFactory.deploy();
    await randomless.deployed();

    const stampFactory = await hre.ethers.getContractFactory("StampNFT");
    const stamp = await stampFactory.deploy("", randomless.address);
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