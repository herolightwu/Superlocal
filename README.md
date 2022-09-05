# Superlocal Contracts Project

This project is contracts project for the Superlocal project. It comes with NFT contracts and Token contracts, unit test for that contract, and a script that deploys that contracts.

    NFT contracts : Mayorship
                    PassportNFT
                    StampNFT
    Token contract : Local

Try running some of the following tasks to check the contracts and unit test:

```shell
npx hardhat help
yarn install

yarn hardhat compile
yarn hardhat test

```

To deploy the contracts on Mainnet or Rinkeby, please create the ".env" file and edit the keys.
".env" file should be created based on ".env.example" file.
To get the needed keys, please go to 'alchemyapi.io' and 'etherscan.io' site, and create the account and the app, and then get the key.
To set the MNEMONIC key in env file, please use the MNEMONIC of your metamask account.

To run the deploy script (refer to package.json): 

```shell
npx hardhat help
yarn hardhat:deploy

```
