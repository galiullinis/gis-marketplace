//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Sale {
    bool isActive;
    address seller;
    address contractAddr;
    uint256 amount;
    uint256 price;
    uint256 startedAt;
    uint256 tokenId;
    InterfaceEnum interFace;
}

struct Auction {
    bool isActive;
    address seller;
    address currentWinner;
    address contractAddr;
    uint256 amount;
    uint256 currentPrice;
    uint256 startedAt;
    uint256 closedAt;
    uint256 bidCount;
    uint256 tokenId;
    InterfaceEnum interFace;
}

enum InterfaceEnum{
    iERC1155,
    iERC721
}
