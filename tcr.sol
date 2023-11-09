// SPDX-License-Identifier: GLP-3.0
pragma solidity ^0.9.0;

contract TCR {
    address public owner;
    uint256 public phase;
    uint256 public upVoteCount;
    uint256 public downVoteCount;
    string public currentCode;
    mapping(address => bool) public hasVoted;
    mapping(address => uint256) public voterTokens; // Saldo de tokens dos eleitores.
    mapping(address => uint256) public voterWeights;

    struct Objection {
        address[] voters;
        bool closed;
    }

    mapping(uint256 => Objection) public objections;

    uint256 public tokenRewardPhase1 = 10; // Recompensa de tokens na Fase 1.
    uint256 public tokenRewardPhase2 = 5;  // Recompensa de tokens na Fase 2.

    constructor() {
        owner = msg.sender;
        phase = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Apenas o dono pode executar esta acao");
        _;
    }

    modifier inPhase(uint256 _phase) {
        require(phase == _phase, "Fase incorreta");
        _;
    }

    //falta a complexidade!!!!
    function setCode(string memory _code) public onlyOwner inPhase(1) {
        currentCode = _code;
    }

    function assignVoterWeight(address _voter, uint256 _weight) public onlyOwner inPhase(1) {
        voterWeights[_voter] = _weight;
    }

    function vote(bool _liked) public inPhase(1) {
        require(!hasVoted[msg.sender], "Voce ja votou.");
        hasVoted[msg.sender] = true;

        if (_liked) {
            upVoteCount += voterWeights[msg.sender];
        } else {
            downVoteCount += voterWeights[msg.sender];
        }

        // Distribui tokens como recompensa na Fase 1.
        voterTokens[msg.sender] += tokenRewardPhase1;
    }

    function endVoting() public onlyOwner inPhase(1) {
        require(upVoteCount > downVoteCount, "O codigo foi rejeitado.");
        phase = 2;
    }

    function startObjection() public onlyOwner inPhase(2) {
        objections[downVoteCount] = Objection({voters: new address[](0), closed: false});
    }

    function voteObjection(bool _accept) public inPhase(2) {
        require(hasVoted[msg.sender] == false, "Voce ja votou.");
        hasVoted[msg.sender] = true;
        require(downVoteCount > upVoteCount, "O codigo nao foi rejeitado.");

        uint256 objectionIndex = downVoteCount;
        Objection storage objection = objections[objectionIndex];

        require(objection.closed == false, "Esta objecao ja foi encerrada.");

        objection.voters.push(msg.sender);

        if (_accept) {
            objection.closed = true;
        }

        // Distribui tokens como recompensa na Fase 2.
        voterTokens[msg.sender] += tokenRewardPhase2;
    }

    function closeObjection() public onlyOwner inPhase(2) {
        require(downVoteCountVoteCount > upVoteCount, "O codigo nao foi rejeitado.");
        uint256 objectionIndex = downVoteCount;
        objections[objectionIndex].closed = true;
    }
}