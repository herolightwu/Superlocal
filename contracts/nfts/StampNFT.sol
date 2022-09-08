// SPDX-License-Identifier: ISC

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "hardhat/console.sol";
import "../interfaces/IRandomness.sol";

contract StampNFT is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    uint256 private constant MAX = ~uint256(0);     // max of uint256 
    uint public constant MAX_SUPPLY = MAX;          // max mintable count
    uint public constant PRICE = 0.01 ether;        // $10 USD , price per each nft mint
    uint public constant MAX_PER_MINT = 1;          // allow to mint one of NFT at one time

    struct Stamp {
        uint level;                                 // lowest level = 1 , max =8
        string image;                               // changable image url
    }

    mapping(uint256 => Stamp) private _properties;
    mapping(uint => string) private _level;         // level name for each level

    IRandomness _rn;

    string public baseTokenURI;
    string public _contractURI;
    string private hiddenMetadataUri = "";
    string private uriSuffix = ".json";
    bool private revealed;

    /// @dev
    event Mint(address);

    constructor(string memory baseURI, address rn) ERC721("StampNFT", "STAMPNFT") {
        setBaseURI(baseURI);

        _rn = IRandomness(rn);

        // initialize _level
        _level[1] = "Red";
        _level[2] = "Orange";
        _level[3] = "Yellow";
        _level[4] = "Green";
        _level[5] = "Blue";
        _level[6] = "Indigo";
        _level[7] = "Violet";
        _level[8] = "Rainbow";

    }

    /// @dev Return the level of the Stamp by StampNFT id
    /// @param _tokenId Token ID of the StampNFT
    function getStampLevel(uint256 _tokenId) public view returns (uint){
        return _properties[_tokenId].level;
    }

    /// @dev Return the image url of the Stamp by StampNFT id
    /// @param _tokenId Token ID of the StampNFT
    function getStampImage(uint256 _tokenId) public view returns (string memory) {
        return _properties[_tokenId].image;
    }

    /// @dev set the image url of the Stamp by StampNFT id
    /// @param _tokenId Token ID of the StampNFT
    /// @param _imgUrl  New image path for the StampNFT
    function setStampImage(uint256 _tokenId, string memory _imgUrl) public onlyOwner {
        _properties[_tokenId].image = _imgUrl;
    }

    /// @dev set hiddenMetadataUri
    /// @param _hiddenMetadataUri default uri for Metadata
    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    /// @dev set uriSuffix
    /// @param _uriSuffix suffix of uri for Metadata
    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    /// @dev non-payable mint function for owner only 
    ///     this function can mint one of Passport only at one time.
    function reserveMint() public onlyOwner {
        uint totalMinted = _tokenIds.current();

        require(totalMinted.add(1) < MAX_SUPPLY, "Not enough NFTs left to reserve");

        _mintSingleNFT();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
        if (bytes(_baseTokenURI).length > 0){
            revealed = true;
        } else {
            revealed = false;
        }
    }

    ///@dev payable mint function
    function mint() public payable {
        uint totalMinted = _tokenIds.current();

        require(totalMinted.add(1) <= MAX_SUPPLY, "Not enough NFTs left!");
        require(msg.value >= PRICE, "Not enough ether to purchase NFTs.");

        _mintSingleNFT();
    }

    /// @dev function to mint one of NFT
    function _mintSingleNFT() private {
        uint newTokenID = _tokenIds.current();
        _safeMint(msg.sender, newTokenID);
        _tokenIds.increment();

        // get the stamp level randomly
        uint slevel = uint(_rn.getRandom(newTokenID) % 8) + 1;
        _properties[newTokenID] = Stamp(slevel, "");
        emit Mint(msg.sender);
    }

    function tokensOfOwner(address _owner) external view returns (uint[] memory) {

        uint tokenCount = balanceOf(_owner);
        uint[] memory tokensId = new uint256[](tokenCount);

        for (uint i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    /// @dev function to withdraw the collected ethers
    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");

        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }
    
    // Opensea Automatic Collection Data

    /// @dev set _contractURI
    /// @param _contURI uri for this json data
    function setContactURI(string memory _contURI) external onlyOwner{
        _contractURI = _contURI;
    }

    function contractURI() public view returns (string memory) {
        // Following link must return this json data.
        // {
        //   "name": "OpenSea Creatures",
        //   "description": "OpenSea Creatures are adorable aquatic beings primarily for demonstrating what can be done using the OpenSea platform. Adopt one today to try out all the OpenSea buying, selling, and bidding feature set.",
        //   "image": "external-link-url/image.png",
        //   "external_link": "external-link-url",
        //   "seller_fee_basis_points": 100, # Indicates a 1% seller fee.
        //   "fee_recipient": "0xA97F337c39cccE66adfeCB2BF99C1DdC54C2D721" # Where seller fees will be paid to.
        // }

        return _contractURI;
    }

   /** RENDER */
    /// @dev return the uri for token id
    /// @param tokenId token id
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {

        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }
}