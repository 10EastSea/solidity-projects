pragma solidity ^0.8.0;

import "./ERC20Contract.sol";
import "./ERC721Contract.sol";

contract AuctionContract {

    ERC20Contract private _erc20;
    ERC721Contract private _erc721;

    // 컨트랙트 배포후, 각 토큰에 대해 approve 권한을 주어야 함! (교환하고자 하는 토큰의 소유주가, approve 함수를, 현 컨트랙트 주소로, 호출해야 함)
    constructor(address erc20, address erc721) { // 토큰 instance 설정
        _erc20 = ERC20Contract(erc20);
        _erc721 = ERC721Contract(erc721);
    }

    struct Auction { // 경매 정보를 저장할 구조체
        address creator; // 경매 생성자
        uint256 tokenId; // 경매 물품 (NFT의 id)

        address currentBidder; // 현재 입찰자 (더 높은 금액을 제시한 사람이 현재 입찰자가 됨)
        uint256 currentBidPrice; // 현재 입찰가 (현재 입찰자가 제시한 금액)

        uint256 startTime; // 경매 시작 시간
        uint256 endTime; // 경매 종료 시간
        bool onGoing; // 경매가 진행 중인지 확인
    }
    
    Auction[] private auctions; // 생성된 경매들을 저장할 배열
    uint256 private _auctionArrTop = 0; // 경매 배열의 맨 끝에 있는 인덱스 값

    ////////////////////////////////////////////////////////////////////////////////////////////////////

    // 경매 생성 (TestSeller > enrollNFT())
    function createAuction(uint256 _tokenId, uint256 _minimumBidPrice, uint256 _endTime) public returns (uint256) {
        require( // 실제 토큰소유자가 호출했는지, 권한 위임(별개)했는지 체크
            _erc721.ownerOf(_tokenId) == msg.sender && // true,
            _erc721.getApproved(_tokenId) == address(this),
            "[AuctionContract] createAuction() error"
        );

        uint256 _startTime = block.timestamp; // 현재 시간 설정
        bool _onGoing = _startTime < _endTime; // 시작 시간이 종료 시간보다 작을 경우 경매 진행 중

        Auction memory auction = Auction({
            creator: msg.sender, // 이 함수를 호출한 사람이 경매 생성자
            tokenId: _tokenId,

            currentBidder: address(0),
            currentBidPrice: _minimumBidPrice,

            startTime: _startTime, 
            endTime: _endTime,
            onGoing: _onGoing
        });

        auctions.push(auction);
        _auctionArrTop++;

        return _auctionArrTop-1;
    }

    // 입찰 제안
    function bidProposal(uint256 _auctionId, uint256 _bidPrice) public returns (uint256) {
        Auction storage auction = auctions[_auctionId];

        require( // 경매가 생성됐는지, 그 경매가 현재 진행 중인지 체크
            auction.creator != address(0) &&
            auction.onGoing,
            "[AuctionContract] bidProposal() error"
        );

        if(_bidPrice > auction.currentBidPrice) { // 제시한 입찰가가 현재 입찰가보다 크다면, 입찰 제안 성공
            auction.currentBidder = msg.sender; // 이 함수를 호출한 사람이 경매 입찰자
            auction.currentBidPrice = _bidPrice;
            return 1;
        }
        return 0;
    }

    // 입찰(경매 종료) (TestSeller > purchaseNFT())
    function bid(uint256 _auctionId) public returns (uint256) {
        Auction storage auction = auctions[_auctionId];

        require( // 경매가 생성됐는지, 그 경매가 종료 됐는지, 입찰자가 있는지 체크
            auction.creator != address(0) &&
            !(auction.onGoing) &&
            auction.currentBidder != address(0),
            "[AuctionContract] bid() error"
        );

        _erc20.transferFrom(auction.currentBidder, auction.creator, auction.currentBidPrice);   // erc20:  구매자 -price-> 판매자 
        _erc721.transferFrom(auction.creator, auction.currentBidder, auction.tokenId);          // erc721: 판매자 -token-> 구매자 
        return 1;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////

    // 경매 정보를 볼 수 있는 get 함수들
    function getCreator(uint256 _auctionId) public view returns (address) { return auctions[_auctionId].creator; }
    function getTokenId(uint256 _auctionId) public view returns (uint256) { return auctions[_auctionId].tokenId; }

    function getCurrentBidder(uint256 _auctionId) public view returns (address) { return auctions[_auctionId].currentBidder; }
    function getCurrentBidPrice(uint256 _auctionId) public view returns (uint256) { return auctions[_auctionId].currentBidPrice; }

    function getStartTime(uint256 _auctionId) public view returns (uint256) { return auctions[_auctionId].startTime; }
    function getEndTime(uint256 _auctionId) public view returns (uint256) { return auctions[_auctionId].endTime; }
    function getOnGoing(uint256 _auctionId) public view returns (bool) { return auctions[_auctionId].onGoing; }

    function setEndAuction(uint256 _auctionId) public { auctions[_auctionId].onGoing = false; } // 경매를 종료시키는 함수 (테스트용 코드)
}
