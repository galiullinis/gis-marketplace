//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IGisERC1155.sol";
import "./IGisERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract GisMarketplace is IERC721Receiver, IERC1155Receiver{
    using Counters for Counters.Counter;

    IGisERC1155 public nftToken1155;
    IGisERC721 public nftToken721;
    IERC20 public erc20Token;
    Counters.Counter private currentTokenId;
    Counters.Counter private currentSaleId;
    Counters.Counter private currentAuctionId;

    uint256 public auctionLimit = 3 days;
    /*
    * Proposals by tokenId.
    */
    mapping(uint256 => Sale) private sales;
    mapping(uint256 => Auction) private auctions;

    /*
    * Marketplace tokens by tokenId.
    */
    mapping(uint256 => MPLToken) private tokens;

    enum Interfaces{
        iERC1155,
        iERC721
    }

    struct MPLToken{
        uint256 nftTokenId;
        string tokenUri;
        Interfaces interFace;
    }

    struct Sale {
        bool isActive;
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        uint256 startedAt;
    }

    struct Auction {
        bool isActive;
        address seller;
        address currentWinner;
        uint256 tokenId;
        uint256 amount;
        uint256 currentPrice;
        uint256 startedAt;
        uint256 closedAt;
        uint256 bidCount;
    }

    event Listed(
        address indexed _seller,
        uint256 indexed _tokenId,
        uint256 indexed _proposalId,
        uint256 _price
    );

    event Bought(
        uint256 indexed _proposalId,
        address indexed _buyer
    );

    event Ended(
        uint256 indexed _proposalId
    );

    constructor(address _nftToken1155Addr,
                address _nftToken721Addr, 
                address _erc20Token){
        nftToken1155 = IGisERC1155(_nftToken1155Addr);
        nftToken721 = IGisERC721(_nftToken721Addr);
        erc20Token = IERC20(_erc20Token);
    }

    function createItem(string memory _tokenURI, address _owner) public {
        createItem(_tokenURI, _owner, 1);
    }
    
    function createItem(string memory _tokenURI, address _owner, uint256 _amount) public {
        require(bytes(_tokenURI).length > 0 && _owner != address(0) && _amount > 0, "incorrect param(s) sended.");
        currentTokenId.increment();

        uint256 tokenId;
        Interfaces _interface;

        if(_amount == 1){
            tokenId = nftToken721.mint(_owner);
            _interface = Interfaces.iERC721;
        } else {
            tokenId = nftToken1155.mint(_owner, _amount, "");
            _interface = Interfaces.iERC1155;
        }

        MPLToken memory mplToken = MPLToken(
            tokenId,
            _tokenURI,
            _interface
        );
        tokens[currentTokenId.current()] = mplToken;
    }

    function listItem(uint256 _id, uint256 _price) public{
        listItem(_id, _price, 1);
    }

    function listItem(uint256 _id, uint256 _price, uint256 _amount) public{
        /*
        * Freeze sender tokens.
        */
        _freezeTokens(_id, _amount);
        currentSaleId.increment();
        uint256 saleId = currentSaleId.current();
        Sale memory proposal = Sale(
            true,
            msg.sender,
            _id,
            _amount,
            _price,
            block.timestamp
        );

        sales[saleId] = proposal;

        emit Listed(msg.sender, _id, saleId, _price);
    }

    function buyItem(uint256 _saleId) public payable{
        require(sales[_saleId].isActive == true, "the token not listed.");
        require(sales[_saleId].seller != msg.sender, "the seller can not buy own token.");
        require(erc20Token.balanceOf(msg.sender) >= sales[_saleId].price, "not enough tokens on balance.");

        /*
        * Sending NFT to buyer
        */
        if (tokens[sales[_saleId].tokenId].interFace == Interfaces.iERC721){
            nftToken721.safeTransferFrom(address(this), msg.sender, tokens[sales[_saleId].tokenId].nftTokenId, "");
        } else {
            nftToken1155.safeTransferFrom(address(this), msg.sender, tokens[sales[_saleId].tokenId].nftTokenId, sales[_saleId].amount, "");
        }

        /*
        * Sending tokens to seller
        */
        erc20Token.transferFrom(msg.sender, sales[_saleId].seller, sales[_saleId].price);

        sales[_saleId].isActive = false;

        emit Bought(_saleId, msg.sender);
    }

    function cancel(uint256 _saleId) public{
        require(sales[_saleId].isActive == true, "the token not listed.");
        require(sales[_saleId].seller == msg.sender, "you are not the seller.");

        /*
        * Unfreeze sender tokens.
        */
        if (tokens[sales[_saleId].tokenId].interFace == Interfaces.iERC721){
            nftToken721.safeTransferFrom(address(this), msg.sender, tokens[sales[_saleId].tokenId].nftTokenId, "");
        } else {
            nftToken1155.safeTransferFrom(address(this), msg.sender, tokens[sales[_saleId].tokenId].nftTokenId, sales[_saleId].amount, "");
        }

        sales[_saleId].isActive = false;

        emit Ended(_saleId);
    }

    function listItemOnAuction(uint256 _id, uint256 _price) public {
        listItemOnAuction(_id, _price, 1);
    }

    function listItemOnAuction(uint256 _id, uint256 _price, uint256 _amount) public {
        /*
        * Freeze sender tokens.
        */
        _freezeTokens(_id, _amount);
        
        currentAuctionId.increment();
        uint256 auctionId = currentAuctionId.current();

        Auction memory auction = Auction(
            true,
            payable(msg.sender),
            address(0),
            _id,
            _amount,
            _price,
            block.timestamp,
            block.timestamp + auctionLimit,
            0
        );

        auctions[auctionId] = auction;

        emit Listed(msg.sender, _id, auctionId, _price);
    }

    function makeBid(uint256 _auctionId, uint256 _price) public payable{
        require(auctions[_auctionId].isActive == true, "the token not listed.");
        require(auctions[_auctionId].seller != msg.sender, "the seller can not make a bid.");
        require(auctions[_auctionId].currentPrice < _price, "not enough tokens sent.");
        require(erc20Token.balanceOf(msg.sender) >= _price, "not enough tokens on balance.");
        require(auctions[_auctionId].closedAt > block.timestamp, "the auction is over.");
        
        if (auctions[_auctionId].currentWinner != address(0)){
            erc20Token.transfer(auctions[_auctionId].currentWinner, auctions[_auctionId].currentPrice);
        }
        // Freeze erc20 tokens
        erc20Token.transferFrom(msg.sender, address(this), _price);
        auctions[_auctionId].currentPrice = _price;
        auctions[_auctionId].currentWinner = msg.sender;
        auctions[_auctionId].bidCount += 1;
    }

    function finishAuction(uint256 _auctionId) public{
        require(auctions[_auctionId].isActive == true, "the token not listed.");
        require(auctions[_auctionId].seller == msg.sender, "you are not the seller.");
        require(auctions[_auctionId].closedAt < block.timestamp, "the auction in progress.");
        
        if (auctions[_auctionId].bidCount > 2){
            /*
            * Sending NFT to winner
            */
            if (tokens[auctions[_auctionId].tokenId].interFace == Interfaces.iERC721){
                nftToken721.safeTransferFrom(address(this), auctions[_auctionId].currentWinner, tokens[auctions[_auctionId].tokenId].nftTokenId, "");
            } else {
                nftToken1155.safeTransferFrom(address(this), auctions[_auctionId].currentWinner, tokens[auctions[_auctionId].tokenId].nftTokenId, auctions[_auctionId].amount, "");
            }
            /*
            * Sending tokens to seller
            */
            erc20Token.transfer(auctions[_auctionId].seller, auctions[_auctionId].currentPrice);
        } else {
            if (auctions[_auctionId].currentWinner != address(0)){
                erc20Token.transfer(auctions[_auctionId].currentWinner, auctions[_auctionId].currentPrice);
            }
            /*
            * Unfreeze NFT 
            */
            if (tokens[auctions[_auctionId].tokenId].interFace == Interfaces.iERC721){
                nftToken721.safeTransferFrom(address(this), auctions[_auctionId].seller, tokens[auctions[_auctionId].tokenId].nftTokenId, "");
            } else {
                nftToken1155.safeTransferFrom(address(this), auctions[_auctionId].seller, tokens[auctions[_auctionId].tokenId].nftTokenId, auctions[_auctionId].amount, "");
            }

        }
        auctions[_auctionId].isActive = false;

        emit Ended(_auctionId);
    }

    function getSale(uint256 _saleId) public view returns(Sale memory){
        return sales[_saleId];
    }

    function getAuction(uint256 _auctionId) public view returns(Auction memory){
        return auctions[_auctionId];
    }

    function getMPLTokenInfo(uint256 _id) public view returns(MPLToken memory){
        return tokens[_id];
    }

    function _freezeTokens(uint256 _id, uint256 _amount) internal {
        if (tokens[_id].interFace == Interfaces.iERC721){
            require(nftToken721.ownerOf(tokens[_id].nftTokenId) == msg.sender, "you don't have enough NFT tokens.");
            nftToken721.safeTransferFrom(msg.sender, address(this), tokens[_id].nftTokenId, "");
        } else {
            require(nftToken1155.balanceOf(msg.sender, tokens[_id].nftTokenId) >= _amount, "you don't have enough NFT tokens.");
            nftToken1155.safeTransferFrom(msg.sender, address(this), tokens[_id].nftTokenId, _amount, "");
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure override returns(bytes4){
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public pure override returns (bytes4){
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool){
        return interfaceId == type(IERC165).interfaceId;
    }
}
