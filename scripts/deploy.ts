import hre from 'hardhat';
import "dotenv/config";

const ethers = hre.ethers
const nftTokenAddr721 = process.env.NFT721_TOKEN_ADDR
const nftTokenAddr1155 = process.env.NFT1155_TOKEN_ADDR
const erc20TokenAddr = process.env.ERC20_TOKEN_ADDR

async function main() {
    const [signer] = await ethers.getSigners()
    const GisMarketplace = await ethers.getContractFactory('GisMarketplace', signer)
    const gisMarketplace = await GisMarketplace.deploy(nftTokenAddr1155, nftTokenAddr721, erc20TokenAddr)
    await gisMarketplace.deployed()
    console.log(gisMarketplace.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });