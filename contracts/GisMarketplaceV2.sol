//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IGisERC1155.sol";
import "./IGisERC721.sol";
import {Sale, Auction, InterfaceEnum} from "./GisMarketplaceStructs.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract GisMarketplaceV2 {
    using Counters for Counters.Counter;

    uint256 constant public auctionLimit = 3 days;

    Counters.Counter private currentTokenId;
    
    /*
    * Proposals by unique ID.
    */
    mapping(uint256 => Sale) private sales;
    mapping(uint256 => Auction) private auctions;

    mapping(address => mapping(InterfaceEnum => bool)) private _contractInterfaces;

    event Listed(
        address indexed _seller,
        uint256 indexed _tokenId,
        uint256 _price
    );

    event Bought(
        uint256 indexed _tokenId,
        address indexed _buyer
    );

    event Ended(
        uint256 indexed _tokenId
    );

    constructor(){}

    function createItem(uint256 _amount, address _contractAddr) public {
        if (IERC165(_contractAddr).supportsInterface(type(IGisERC1155).interfaceId)){
            _contractInterfaces[_contractAddr][InterfaceEnum.iERC1155] = true;
            IGisERC1155(_contractAddr).mint(msg.sender, _amount, "");
        } else if (IERC165(_contractAddr).supportsInterface(type(IGisERC721).interfaceId)){
            _contractInterfaces[_contractAddr][InterfaceEnum.iERC721] = true;
            IGisERC721(_contractAddr).mint(msg.sender);
        }
    }

    function listItem(uint256 _id, uint256 _price, uint256 _amount, address _contractAddr) public{
        require(auctions[_id].isActive == false, "the token on auction.");
        require(sales[_id].isActive == false, "the token has already been listed.");

        if (_contractInterfaces[_contractAddr][InterfaceEnum.iERC1155]){
            _listERC1155(_id, _price, _amount, _contractAddr, InterfaceEnum.iERC1155);
        } else if (_contractInterfaces[_contractAddr][InterfaceEnum.iERC721]){
            _listERC721(_id, _price, _amount, _contractAddr, InterfaceEnum.iERC721);
        } else {
            if (IERC165(_contractAddr).supportsInterface(type(IERC1155).interfaceId)){
                _contractInterfaces[_contractAddr][InterfaceEnum.iERC1155] = true;
                _listERC1155(_id, _price, _amount, _contractAddr, InterfaceEnum.iERC1155);
            } else if (IERC165(_contractAddr).supportsInterface(type(IERC721).interfaceId)){
                _contractInterfaces[_contractAddr][InterfaceEnum.iERC721] = true;
                _listERC721(_id, _price, _amount, _contractAddr, InterfaceEnum.iERC721);
            }
        }
    }

    function _listERC1155(uint256 _id, uint256 _price, uint256 _amount, address _contractAddr, InterfaceEnum interFace) private {
        require(IERC1155(_contractAddr).balanceOf(msg.sender, _id) >= _amount, "not enough items on seller balance.");
        _listItem(_id, _price, _amount, _contractAddr, interFace);
    }

    function _listERC721(uint256 _id, uint256 _price, uint256 _amount, address _contractAddr, InterfaceEnum interFace) private {
        require(IERC721(_contractAddr).ownerOf(_id) == msg.sender, "not enough items on seller balance.");
        _listItem(_id, _price, _amount, _contractAddr, interFace);
    }

    function _listItem(uint256 _id, uint256 _price, uint256 _amount, address _contractAddr, InterfaceEnum _interFace) private{
        currentTokenId.increment();

        Sale memory proposal = Sale(
            true,
            msg.sender,
            _contractAddr,
            _amount,
            _price,
            block.timestamp,
            _id,
            _interFace
        );

        sales[currentTokenId.current()] = proposal;

        emit Listed(msg.sender, currentTokenId.current(), _price);
    }

    function buyItem(uint256 _id) public payable{
        require(auctions[_id].isActive == false, "the token on auction.");
        require(sales[_id].isActive == true, "the token not listed.");
        require(sales[_id].seller != msg.sender, "the seller can not buy own token.");
        require(sales[_id].price == msg.value, "not enough eth sent.");

        if (sales[_id].interFace == InterfaceEnum.iERC1155){
            IERC1155(sales[_id].contractAddr).safeTransferFrom(sales[_id].seller, msg.sender, sales[_id].tokenId, sales[_id].amount, "");
        } else {
            IERC721(sales[_id].contractAddr).safeTransferFrom(sales[_id].seller, msg.sender, sales[_id].tokenId, "");
        }

        payable(sales[_id].seller).transfer(sales[_id].price);
        sales[_id].isActive = false;

        emit Bought(_id, msg.sender);
    }

    function cancel(uint256 _id) public{
        require(auctions[_id].isActive == false, "the token on auction.");
        require(sales[_id].isActive == true, "the token not listed.");
        require(sales[_id].seller == msg.sender, "you are not the seller.");
        
        sales[_id].isActive = false;

        emit Ended(_id);
    }

    function listItemOnAuction(uint256 _id, uint256 _price, uint256 _amount, address _contractAddr) public{
        require(sales[_id].isActive == false, "the token on sale.");
        require(auctions[_id].isActive == false, "the token has already been listed.");

        if (_contractInterfaces[_contractAddr][InterfaceEnum.iERC1155]){
            _listAuctionERC1155(_id, _price, _amount, _contractAddr, InterfaceEnum.iERC1155);
        } else if (_contractInterfaces[_contractAddr][InterfaceEnum.iERC721]){
            _listAuctionERC721(_id, _price, _amount, _contractAddr, InterfaceEnum.iERC721);
        } else {
            if (IERC165(_contractAddr).supportsInterface(type(IERC1155).interfaceId)){
                _contractInterfaces[_contractAddr][InterfaceEnum.iERC1155] = true;
                _listAuctionERC1155(_id, _price, _amount, _contractAddr, InterfaceEnum.iERC1155);
            } else if (IERC165(_contractAddr).supportsInterface(type(IERC721).interfaceId)){
                _contractInterfaces[_contractAddr][InterfaceEnum.iERC721] = true;
                _listAuctionERC721(_id, _price, _amount, _contractAddr, InterfaceEnum.iERC721);
            }
        }
    }

    function _listAuctionERC1155(uint256 _id, uint256 _price, uint256 _amount, address _contractAddr, InterfaceEnum interFace) private {
        require(IERC1155(_contractAddr).balanceOf(msg.sender, _id) >= _amount, "not enough items on seller balance.");
        _listItemOnAuction(_id, _price, _amount, _contractAddr, interFace);
    }

    function _listAuctionERC721(uint256 _id, uint256 _price, uint256 _amount, address _contractAddr, InterfaceEnum interFace) private {
        require(IERC721(_contractAddr).ownerOf(_id) == msg.sender, "not enough items on seller balance.");
        _listItemOnAuction(_id, _price, _amount, _contractAddr, interFace);
    }

    function _listItemOnAuction(uint256 _id, uint256 _price, uint256 _amount, address _contractAddr, InterfaceEnum interFace) private {
        currentTokenId.increment();

        Auction memory auction = Auction(
            true,
            payable(msg.sender),
            address(0),
            _contractAddr,
            _amount,
            _price,
            block.timestamp,
            block.timestamp + auctionLimit,
            0,
            _id,
            interFace
        );

        auctions[currentTokenId.current()] = auction;

        emit Listed(msg.sender, currentTokenId.current(), _price);
    }

    function makeBid(uint256 _id) public payable{
        require(sales[_id].isActive == false, "the token on sale.");
        require(auctions[_id].isActive == true, "the token not listed.");
        require(auctions[_id].seller != msg.sender, "the seller can not make a bid.");
        require(auctions[_id].currentPrice < msg.value, "not enough eth sent.");
        require(auctions[_id].closedAt > block.timestamp, "the auction is over.");
        
        if (auctions[_id].currentWinner != address(0)){
            payable(auctions[_id].currentWinner).transfer(auctions[_id].currentPrice);
        }
        auctions[_id].currentPrice = msg.value;
        auctions[_id].currentWinner = msg.sender;
        auctions[_id].bidCount += 1;
    }

    function finishAuction(uint256 _id) public{
        require(sales[_id].isActive == false, "the token on sale.");
        require(auctions[_id].isActive == true, "the token not listed.");
        require(auctions[_id].seller == msg.sender, "you are not the seller.");
        require(auctions[_id].closedAt < block.timestamp, "the auction in progress.");
        
        if (auctions[_id].bidCount > 2){
            if (auctions[_id].interFace == InterfaceEnum.iERC1155){
                IERC1155(auctions[_id].contractAddr).safeTransferFrom(auctions[_id].seller, auctions[_id].currentWinner, auctions[_id].tokenId, auctions[_id].amount, "");
            } else {
                IERC721(auctions[_id].contractAddr).safeTransferFrom(auctions[_id].seller, auctions[_id].currentWinner, auctions[_id].tokenId, "");
            }
            payable(auctions[_id].seller).transfer(auctions[_id].currentPrice);
        } else {
            if (auctions[_id].currentWinner != address(0)){
                payable(auctions[_id].currentWinner).transfer(auctions[_id].currentPrice);
            }
        }
        auctions[_id].isActive = false;

        emit Ended(_id);
    }

    function cancelAuction(uint256 _id) public{
        require(sales[_id].isActive == false, "the token on sale.");
        require(auctions[_id].isActive == true, "the token not listed.");
        require(auctions[_id].seller == msg.sender, "you are not the seller.");
        require(auctions[_id].bidCount == 0, "the auction has begun.");
        
        auctions[_id].isActive = false;

        emit Ended(_id);
    }

    function getSale(uint256 _id) public view returns(Sale memory){
        return sales[_id];
    }

    function getAuction(uint256 _id) public view returns(Auction memory){
        return auctions[_id];
    }
}
