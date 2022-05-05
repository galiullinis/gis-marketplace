import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract } from "ethers";
import { ethers } from "hardhat";

describe("GisMarketplace", () => {
    let owner: SignerWithAddress;
    let nftToken1155: Contract;
    let nftToken721: Contract;
    let erc20Token: Contract;
    let marketplace: Contract;
    let account1: SignerWithAddress;
    let account2: SignerWithAddress;
    let account3: SignerWithAddress;
    const createItemsCount = 11;
    const sellItemsCount = 10;
    const sellPrice = 100;
    const auctionDuration = 3 * 24* 60 * 60;
    const erc20MintAmount = 10000

    const notActiveRevertedMsg = "the token not listed."
    const auctionOverRevertedMsg = "the auction is over."
    const notEnoughBalanceRevertedMsg = "you don't have enough NFT tokens."
    const notSellerRevertedMsg = "you are not the seller."
    const notEnoughTokensRevertedMsg = "not enough tokens on balance."
    const notEnoughTokensSentRevertedMsg = "not enough tokens sent."

    const tokenURI = "https://token.uri/1.json"
    const tokenBaseUrl = "https://bafybeiek3erxmgc3udrjwuuuoq6hktq2nw74xmqgvgcxdy5dcti7exc3ja.ipfs.nftstorage.link/ipfs/bafybeiek3erxmgc3udrjwuuuoq6hktq2nw74xmqgvgcxdy5dcti7exc3ja/"
    
    async function listItem(id: number = 1) {
        return marketplace.connect(account1)["listItem(uint256,uint256)"](id, sellPrice)
    }

    async function listItem1155(id: number = 1) {
        return marketplace.connect(account1)["listItem(uint256,uint256,uint256)"](id, sellPrice, sellItemsCount)
    }

    async function listItemOnAuction(account: SignerWithAddress = account1) {
        return marketplace.connect(account)["listItemOnAuction(uint256,uint256)"](1, sellPrice)
    }

    async function listItemOnAuction1155(id: number = 1, account: SignerWithAddress = account1) {
        return marketplace.connect(account)["listItemOnAuction(uint256,uint256,uint256)"](id, sellPrice, sellItemsCount)
    }

    async function makeBid(id: number, price: number, account: SignerWithAddress = account1){
        return marketplace.connect(account).makeBid(id, price)
    }

    async function finishAuction(id: number, account: SignerWithAddress = account1) {
        return marketplace.connect(account).finishAuction(id)
    }

    beforeEach(async () => {
        [owner, account1, account2, account3] = await ethers.getSigners()

        const GisERC1155Token = await ethers.getContractFactory("GisERC1155Token", owner)
        nftToken1155 = await GisERC1155Token.deploy(tokenBaseUrl)
        await nftToken1155.deployed()

        const GisERC721Token = await ethers.getContractFactory("GisERC721Token", owner)
        nftToken721 = await GisERC721Token.deploy("TokenName", "TokenSymbol")
        await nftToken721.deployed()

        const GisERC20Token = await ethers.getContractFactory("GisToken", owner)
        erc20Token = await GisERC20Token.deploy("TokenName", "TokenSymbol")
        await erc20Token.deployed()

        const GisMarketplace = await ethers.getContractFactory("GisMarketplace", owner)
        marketplace = await GisMarketplace.deploy(nftToken1155.address, nftToken721.address, erc20Token.address)
        await marketplace.deployed()

        await nftToken1155.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")), marketplace.address)
        await nftToken1155.connect(account1).setApprovalForAll(marketplace.address, true)
        await nftToken721.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")), marketplace.address)
        await nftToken721.connect(account1).setApprovalForAll(marketplace.address, true)
        await erc20Token.connect(account2).approve(marketplace.address, 10000000)
        await erc20Token.connect(account3).approve(marketplace.address, 10000000)
        await erc20Token.mint(account2.address, erc20MintAmount)
        await erc20Token.mint(account3.address, erc20MintAmount)
    })

    it("create item 721", async () => {
        await expect(marketplace.connect(account1)["createItem(string,address)"]("", account1.address)).to.be.revertedWith("incorrect param(s) sended.")
        await marketplace.connect(account1)["createItem(string,address)"](tokenURI, account1.address)
        expect(await nftToken721.balanceOf(account1.address)).to.eq(1)
        expect(await nftToken721.ownerOf(1)).to.eq(account1.address)
        const mplToken = await marketplace.getMPLTokenInfo(1)
        expect(mplToken.nftTokenId).to.eq(1)
        expect(mplToken.tokenUri).to.eq(tokenURI)
        expect(mplToken.interFace).to.eq(1)
    })

    it("create item 1155", async () => {
        await marketplace.connect(account1)["createItem(string,address,uint256)"](tokenURI, account1.address, createItemsCount)
        expect(await nftToken1155.balanceOf(account1.address, 1)).to.eq(createItemsCount)
        const mplToken = await marketplace.getMPLTokenInfo(1)
        expect(mplToken.nftTokenId).to.eq(1)
        expect(mplToken.tokenUri).to.eq(tokenURI)
        expect(mplToken.interFace).to.eq(0)
    })

    it("list item without balance", async () => {
        await expect(marketplace.connect(account1)["listItem(uint256,uint256)"](1, sellPrice)).to.be.revertedWith(notEnoughBalanceRevertedMsg)
    })

    describe("sales", () => {
        beforeEach(async () => {
            await marketplace.connect(account1)["createItem(string,address)"](tokenURI, account1.address)
            await marketplace.connect(account1)["createItem(string,address,uint256)"](tokenURI, account1.address, createItemsCount)
            expect(await nftToken721.balanceOf(account1.address)).to.eq(1)
            expect(await nftToken721.ownerOf(1)).to.eq(account1.address)
            expect(await nftToken1155.balanceOf(account1.address, 1)).to.eq(createItemsCount)
        })

        it("list item", async () => {
            const tx = await listItem()
            await expect(listItem()).to.be.revertedWith(notEnoughBalanceRevertedMsg)

            const [isActive] = await marketplace.getSale(1)
            expect(isActive).to.eq(true)

            await expect(tx).to.emit(marketplace, "Listed").withArgs(account1.address, 1, 1, sellPrice)
        })

        it("buy item reverts", async () => {
            const sellerBuyRevertedMsg = "the seller can not buy own token."

            await expect(marketplace.buyItem(2)).to.be.revertedWith(notActiveRevertedMsg)
            await listItem()
            await expect(marketplace.connect(account1).buyItem(1)).to.be.revertedWith(sellerBuyRevertedMsg)
            await expect(marketplace.buyItem(1)).to.be.revertedWith(notEnoughTokensRevertedMsg)
        })

        it("buy item 721", async () => {
            await listItem()

            const tx = await marketplace.connect(account2).buyItem(1)
            expect(await erc20Token.balanceOf(account2.address)).to.eq(erc20MintAmount - sellPrice)
            expect(await erc20Token.balanceOf(account1.address)).to.eq(sellPrice)

            expect(await nftToken721.ownerOf(1)).to.eq(account2.address)
            const [isActive] = await marketplace.getSale(1)
            expect(isActive).to.eq(false)
            await expect(tx).to.emit(marketplace, "Bought").withArgs(1, account2.address)
        })

        it("buy item 1155", async () => {
            await listItem1155(2)

            const tx = await marketplace.connect(account2).buyItem(1)
            expect(await erc20Token.balanceOf(account2.address)).to.eq(erc20MintAmount - sellPrice)
            expect(await erc20Token.balanceOf(account1.address)).to.eq(sellPrice)

            expect(await nftToken1155.balanceOf(account2.address, 1)).to.eq(sellItemsCount)
            expect(await nftToken1155.balanceOf(account1.address, 1)).to.eq(createItemsCount - sellItemsCount)
            const [isActive] = await marketplace.getSale(1)
            expect(isActive).to.eq(false)
            await expect(tx).to.emit(marketplace, "Bought").withArgs(1, account2.address)
        })

        it("cancel the sale 721", async () => {
            await expect(marketplace.connect(account1).cancel(1)).to.be.revertedWith(notActiveRevertedMsg)
            await listItem()
            await expect(marketplace.connect(account2).cancel(1)).to.be.revertedWith(notSellerRevertedMsg)
            
            const tx = await marketplace.connect(account1).cancel(1)
            const [isActive] = await marketplace.getSale(1)
            expect(isActive).to.eq(false)
            await expect(tx).to.emit(marketplace, "Ended").withArgs(1)
        })

        it("cancel the sale 1155", async () => {
            await listItem1155(2)
            
            const tx = await marketplace.connect(account1).cancel(1)
            const [isActive] = await marketplace.getSale(1)
            expect(isActive).to.eq(false)
            await expect(tx).to.emit(marketplace, "Ended").withArgs(1)
        })
    })

    describe("auctions", () => {
        beforeEach(async () => {
            await marketplace.connect(account1)["createItem(string,address)"](tokenURI, account1.address)
            await marketplace.connect(account1)["createItem(string,address,uint256)"](tokenURI, account1.address, createItemsCount)
            expect(await nftToken721.balanceOf(account1.address)).to.eq(1)
            expect(await nftToken721.ownerOf(1)).to.eq(account1.address)
        })

        it("list item on auction", async () => {
            await expect(listItemOnAuction(owner)).to.be.revertedWith(notEnoughBalanceRevertedMsg)
            const tx = await listItemOnAuction()
            await expect(listItemOnAuction()).to.be.revertedWith(notEnoughBalanceRevertedMsg)
            await expect(tx).to.emit(marketplace, "Listed").withArgs(account1.address, 1, 1, sellPrice)
        })

        it("make bid reverts", async () => {
            const sellerBidRevertedMsg = "the seller can not make a bid."
            await expect(makeBid(1, 150)).to.be.revertedWith(notActiveRevertedMsg)

            await listItemOnAuction()
            await expect(makeBid(1, 150)).to.be.revertedWith(sellerBidRevertedMsg)
            await expect(makeBid(1, 10, account2)).to.be.revertedWith(notEnoughTokensSentRevertedMsg)
            await expect(makeBid(1, 300, owner)).to.be.revertedWith(notEnoughTokensRevertedMsg)
        
            await ethers.provider.send(
                "evm_increaseTime",
                [auctionDuration + 1000]
            )

            await expect(makeBid(1, 101, account2)).to.be.revertedWith(auctionOverRevertedMsg)
        })

        it("make bid", async () => {
            await listItemOnAuction()

            const tx = await makeBid(1, 150, account2)
            expect(await erc20Token.balanceOf(account2.address)).to.eq(erc20MintAmount - 150)
            expect(await erc20Token.balanceOf(marketplace.address)).to.eq(150)

            const auction = await marketplace.getAuction(1)
            expect(auction.currentWinner).to.eq(account2.address)
            expect(auction.currentPrice).to.eq(150)
        })

        it("return tokens after bid", async () => {
            await listItemOnAuction()
            
            await makeBid(1, 150, account2)
            const tx = await makeBid(1, 200, account3)
            expect(await erc20Token.balanceOf(account2.address)).to.eq(erc20MintAmount)
            expect(await erc20Token.balanceOf(account3.address)).to.eq(erc20MintAmount - 200)
        })

        it("finish auction reverts", async () => {
            const inProgressRevertedMsg = "the auction in progress."
            await expect(finishAuction(1, account1)).to.be.revertedWith(notActiveRevertedMsg)

            await listItemOnAuction()
            await expect(finishAuction(1, account2)).to.be.revertedWith(notSellerRevertedMsg)
            await expect(finishAuction(1, account1)).to.be.revertedWith(inProgressRevertedMsg)
        })

        it("finish auction with 0 bid", async () => {
            await listItemOnAuction()

            await ethers.provider.send(
                "evm_increaseTime",
                [auctionDuration + 1000]
            )

            const tx = await finishAuction(1, account1)
            expect((await marketplace.getAuction(1)).isActive).to.eq(false)
            await expect(tx).to.emit(marketplace, "Ended").withArgs(1)
        })

        it("finish auction with 0 bid 1155", async () => {
            await listItemOnAuction1155(2)

            await ethers.provider.send(
                "evm_increaseTime",
                [auctionDuration + 1000]
            )

            const tx = await finishAuction(1, account1)
            expect((await marketplace.getAuction(1)).isActive).to.eq(false)
            await expect(tx).to.emit(marketplace, "Ended").withArgs(1)
        })

        it("finish auction with 1 bid", async () => {
            await listItemOnAuction()

            await makeBid(1, 150, account2)
            await ethers.provider.send(
                "evm_increaseTime",
                [auctionDuration + 1000]
            )
            const tx = await finishAuction(1, account1)

            expect(await erc20Token.balanceOf(account2.address)).to.eq(erc20MintAmount)
            expect(await erc20Token.balanceOf(marketplace.address)).to.eq(0)
        })

        it("finish auction with more than 2 bids", async () => {
            await listItemOnAuction()

            await makeBid(1, 150, account2)
            await makeBid(1, 200, account3)
            await makeBid(1, 250, account2)

            await ethers.provider.send(
                "evm_increaseTime",
                [auctionDuration + 1000]
            )

            await finishAuction(1, account1)
            expect(await nftToken721.ownerOf(1)).to.eq(account2.address)
            expect(await erc20Token.balanceOf(account1.address)).to.eq(250)
            expect(await erc20Token.balanceOf(marketplace.address)).to.eq(0)
        })

        it("finish auction with more than 2 bids 1155", async () => {
            await listItemOnAuction1155(2)

            await makeBid(1, 150, account2)
            await makeBid(1, 200, account3)
            await makeBid(1, 250, account2)

            await ethers.provider.send(
                "evm_increaseTime",
                [auctionDuration + 1000]
            )

            await finishAuction(1, account1)
            expect(await nftToken1155.balanceOf(account2.address, 1)).to.eq(sellItemsCount)
        })

        it("check interfaceId for IERC165", async () => {
            expect(await marketplace.supportsInterface("0x01ffc9a7")).to.eq(true)
        })
    })
})