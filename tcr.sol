// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TCR {
    address owner;
    string public javaCode;
    uint256 public complexity;
    uint256 public duration;
    uint256 public groupSize;
    uint256 public voterCount;
    uint8[] public waiting;

    mapping(address => bool) hasVoted;
    mapping(address => uint8) groupLetter;
    mapping(address => int8) javaVote;
    mapping(uint8 => mapping(uint256 => mapping(address => int8))) objectionVote;
    mapping(uint8 => mapping(uint256 => mapping(address => bool))) hasVotedForObjection;

    struct Group {
        address[] members;
        Objection[] objections;
        uint256 phaseEndTime;
        uint256 phaseStartTime;
        int256[] currentObjection; //0 indice, 1 vencedora na primeira fase, 2 atual para o primeiro grupo a ser reavaliado 3 atual para o segundo grupo a ser reavaliado
        int256 javaCodeVote;
    }

    struct Objection {
        address creator;
        string description;
        uint256 endTime;
        uint256 startTime;
        int256 objectionVote;
        int256 subject;
        bool resolved;
    }

    Group[3] groups; //A (0), B (1), C (2)

    enum Phase { Initialization, Phase1, Phase2, Phase3, Ended}

    Phase public currentPhase = Phase.Initialization;

    modifier onlyDuringPhase(Phase _phase) {
        require(currentPhase == _phase, "Function can only be called during a specific phase");
        _;
    }

    constructor(string memory _javaCode, uint256 _complexity, uint256 _groupSize) {
        owner = msg.sender;
        javaCode = _javaCode;
        complexity = _complexity;
        groupSize = _groupSize;
        duration = complexity * 86400;
    }

    event EvaluationCompleted(string result);
    event TransitionToPhase(Phase indexed phase);

    function checkObjection(uint8 _index) internal returns (string memory, uint256) {
        uint8 letter;

        letter = groupLetter[msg.sender];
        require (letter > 0 && groups[letter].currentObjection[_index] >= 0, "No objection yet");
        checkObjectionTime(letter);
        return (groups[letter].objections[uint(groups[letter].currentObjection[_index])].description,
        groups[letter].objections[uint(groups[letter].currentObjection[_index])].endTime);
    }

    function checkPhase1() external onlyDuringPhase(Phase.Phase1) returns (string memory, uint256) {
        return checkObjection(0);
    }

    function checkPhase2(uint8 _index) external onlyDuringPhase(Phase.Phase2) returns (string memory, uint256) {
        return checkObjection(_index);
    }

    function checkGroupsEndTime() external returns (uint256, uint256, uint256) {
        checkPhaseTransition();
        return (groups[0].phaseEndTime, groups[1].phaseEndTime, groups[2].phaseEndTime);
    }

    function checkObjectionTime(uint8 letter) internal returns (uint8) { //mudei 21/12
        uint256 index;

        index = uint(groups[letter].currentObjection[0]);
        if (groups[letter].currentObjection[0] >= 0 &&
        block.timestamp > groups[letter].objections[index].endTime &&
        groups[letter].objections[index].objectionVote > 0) {
            groups[letter].objections[index].resolved = true;
            waiting[letter] = 1;
            return 1;
        }
        else {
            return 0;
        }
    }

    function checkPhaseTransition() internal returns (bool) {
        uint checkSum;
        bool keep;

        for (uint8 i = 0; i < 3; i++) {
            if (waiting[i] == 0) {
                if (block.timestamp > groups[0].phaseEndTime) {
                    waiting[i] = 1;
                }
            }
            checkSum += waiting[i]; //mudei 21/12
        }
        if (checkSum == 3) {
            phaseTransition();
            keep = false;
        }
        else {
            keep = true;
        }
        return keep;
    }

    function checkWinningObjections1() external view onlyDuringPhase(Phase.Phase2) returns (string memory, string memory, string memory) {
        uint8 letter;

        letter = groupLetter[msg.sender];
        require (letter > 0, "Invalid caller");
        return (groups[0].objections[uint(groups[0].currentObjection[1])].description,
        groups[1].objections[uint(groups[1].currentObjection[1])].description,
        groups[2].objections[uint(groups[2].currentObjection[1])].description);
    }

    function initialize() external onlyDuringPhase(Phase.Initialization) {
        require(groupLetter[msg.sender] == 0 && voterCount < groupSize * 3, "All groups are already filled");

        if (voterCount % 3 == 0) {
            groups[0].members.push(msg.sender);
            groupLetter[msg.sender] = 1;
        } else if (voterCount % 3 == 1) {
            groups[1].members.push(msg.sender);
            groupLetter[msg.sender] = 2;
        } else {
            groups[2].members.push(msg.sender);
            groupLetter[msg.sender] = 3;
        }

        if (voterCount == groupSize * 3) {
            for (uint8 i = 0; i < 3; i++) {
                groups[0].currentObjection[i] = -1;
                groups[1].currentObjection[i] = -1;
                groups[2].currentObjection[i] = -1;
            }
            phaseTransition();
        }
        voterCount++;
    }

    function phaseTransition() internal { //mudei 21/12
        uint8 increase;

        if (currentPhase == Phase.Initialization) {
            increase = 1;
            currentPhase = Phase.Phase1;
            emit TransitionToPhase(Phase.Phase1);
        }
        else if (currentPhase == Phase.Phase1) {
            uint8 checkSum;
            for (uint8 i = 0; i < 3; i++) {
                checkSum += checkObjectionTime(i);
            }
            if (checkSum == 3) {
                for (uint8 i = 0; i < 3; i++) {
                    groups[i].currentObjection[1] = groups[i].currentObjection[0];
                }
                increase = 2;
                currentPhase = Phase.Phase2;
                emit TransitionToPhase(Phase.Phase2);
            }
            else {
                increase = 0;
                currentPhase = Phase.Ended;
                emit TransitionToPhase(Phase.Ended);
                emit EvaluationCompleted("Approved");
            }
        }
        else if (currentPhase == Phase.Phase2) {
            increase = 3;
            currentPhase = Phase.Phase3;
            emit TransitionToPhase(Phase.Phase3);
        }
        for (uint8 i = 0; i < 3; i++) {
            groups[i].phaseEndTime += increase * duration;
            groups[i].phaseStartTime = block.timestamp;
            waiting[i] = 0;
        }
    }

    function raiseObjection(string memory _description, int256 _subject) internal returns (string memory) {
        if (checkPhaseTransition()) {
            uint8 letter;
            uint256 index;

            letter = groupLetter[msg.sender];
            if (letter > 0) {
                letter--;
            }
            else {
                return "Invalid caller";
            }
            checkObjectionTime(letter);
            index = uint(groups[letter].currentObjection[0]);
            if (groups[letter].currentObjection[0] >= 0) {
                if (!(waiting[letter] == 0 &&
                block.timestamp > groups[letter].objections[index].endTime)) {
                    return "The current objection is still running";
                }
            }
            groups[letter].objections.push(Objection({creator: msg.sender, description: _description,
            endTime: block.timestamp + duration / 5, startTime: block.timestamp, objectionVote: 0,
            subject: _subject, resolved: false}));
            groups[letter].currentObjection[0]++;
            groups[letter].phaseEndTime += duration / 5;
            return "Objection raised";
        }
        else {
            return "Phase over";
        }
    }

    function raisePhase1(string memory _description) external onlyDuringPhase(Phase.Phase1) returns (string memory) {
        return raiseObjection(_description, -1);
    }

    function raisePhase2(string memory _description, int256 _subject) external onlyDuringPhase(Phase.Phase2) returns (string memory) {
        return raiseObjection(_description, _subject);
    }

    function voteJavaCode(int8 vote) external onlyDuringPhase(Phase.Phase1) returns (string memory) {
        if (checkPhaseTransition()) {
            if (!(vote == 1 || vote == -1)) {
                return "Invalid vote value. Should be 1 (like) or -1 (dislike)";
            }

            uint8 letter;

            letter = groupLetter[msg.sender];
            if (letter > 0) {
                letter--;
            }
            else {
                return "Invalid caller";
            }
            checkObjectionTime(letter);
            if (hasVoted[msg.sender]) {
                groups[letter].javaCodeVote -= javaVote[msg.sender]; //Reverting vote
            }

            if (vote == 1) {
                groups[letter].javaCodeVote++;
            }
            else {
                groups[letter].javaCodeVote--;
            }
            hasVoted[msg.sender] = true;
            javaVote[msg.sender] = vote;
            return "Success";
        }
        else {
            return "Phase over";
        }
    }

    function voteObjection(int256 _subject, int8 _vote) internal returns (string memory) {
        uint8 letter;
        uint256 index;

        letter = groupLetter[msg.sender];
        checkObjectionTime(letter);
        if (letter > 0) {
            letter--;
        }
        else {
            return "Invalid caller";
        }
        index = uint(groups[letter].currentObjection[0]);
        if (groups[letter].currentObjection[0] >= 0) {
            if (!(waiting[letter] == 0 &&
            block.timestamp < groups[letter].objections[index].endTime)) {
                return "The current objection is closed";
            }

            if (hasVotedForObjection[letter][index][msg.sender]) {
                groups[letter].objections[index].objectionVote -= objectionVote[letter][index][msg.sender];
            }
        }
        groups[letter].objections[index].objectionVote += _vote;
        hasVotedForObjection[letter][index][msg.sender] = true;
        objectionVote[letter][index][msg.sender] = _vote;
        if (_subject > 0) {
            groups[letter].currentObjection[uint(_subject) + 1] = groups[letter].currentObjection[0];
        }
        return "Succes";
    }

    //atribuir depois de votar
    function votePhase1(int8 _vote) external onlyDuringPhase(Phase.Phase1) returns (string memory) {
        return voteObjection(-1, _vote);
    }

    function votePhase2(int256 _subject, int8 _vote) external onlyDuringPhase(Phase.Phase2) returns (string memory) {
        return voteObjection(_subject, _vote);
    }
}
