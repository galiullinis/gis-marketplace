import { task } from 'hardhat/config'
import { abi } from '../artifacts/contracts/GisMarketplace.sol/GisMarketplace.json'


task("createItem", "Creates item on marketplace")
    .addParam("contract", "Contract address")
    .addParam("account", "Recipient address")
    .addParam("tokenUri", "Token URI")
    .addOptionalParam("amount", "Amount of tokens(unnecessary)")
    .setAction(async (taskArgs, { ethers }) => {
        const [signer] = await ethers.getSigners()
        const contract = taskArgs.contract
        const account = taskArgs.account
        const tokenUri = taskArgs.tokenUri
        const amount = taskArgs.amount
        const marketplace = new ethers.Contract(
            contract,
            abi,
            signer
        )

        let tx;

        if (amount === undefined){
            tx = await marketplace["createItem(string,address)"](tokenUri, account)
        } else {
            tx = await marketplace["createItem(string,address,uint256)"](tokenUri, account, amount)
        }
        console.log(tx)
    })