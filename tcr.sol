// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol"; //ERC20


contract TCR {
    address owner;
    string public javaCode;
    uint256 public complexity;
    uint256 public duration;
    uint256 public groupSize;
    uint256 public voterCount;
    uint8[3] public waiting;

    uint256 phaseEndTime_middle;
    uint256 phaseStartTime_middle;
    uint256 voterCount_middle;

    IERC20 public immutable TCRtoken0; //ERC20

    uint8 buffer;

    mapping(address => bool) hasVoted;
    mapping(address => uint8) groupLetter;
    mapping(address => int8) javaVote;
    mapping(uint8 => mapping(uint256 => mapping(address => int8))) objectionVote;
    mapping(uint8 => mapping(uint256 => mapping(address => bool))) hasVotedForObjection;
    mapping(address => uint) public balanceOf; //ERC20

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
        int8 resolved;
        int256 objectionVote;
        int256 subject;
    }

    Group[4] groups; //A (0), B (1), C (2), D (3)

    enum Phase { Initialization, Phase1, Phase2, Middle, Phase3, Ended}

    Phase public currentPhase = Phase.Initialization;

    modifier onlyDuringPhase(Phase _phase) {
        require(currentPhase == _phase, "Function can only be called during a specific phase");
        _;
    }

    constructor(address TCRtokenContract, string memory _javaCode, uint256 _complexity, uint256 _groupSize) {
        TCRtoken0 = IERC20(TCRtokenContract);
        
        owner = msg.sender;
        javaCode = _javaCode;
        complexity = _complexity;
        groupSize = _groupSize;
        duration = complexity * 86400;
    }



    event EvaluationCompleted(string result);
    event TransitionToPhase(Phase indexed phase);

    //Token distribution
    function distributeTokensToGroupMembers(uint groupId) internal {
        require(groups[groupId].members.length > 0, "No members in the group");

        uint256 amountPerMember = calculateTokenAmount(groupId);

        for (uint i = 0; i < groups[groupId].members.length; i++) {
            address member = groups[groupId].members[i];
            TCRtoken0.transfer(member, amountPerMember);
        }
    }

    function calculateTokenAmount(uint groupId) internal view returns (uint256) {
        uint256 amount = 100; // Example fixed amount
        return amount;
    }




    //teste apenas
    function avancarFase() external {
        phaseTransition();
    }

    //teste apenas
    function verificarGrupo() external view returns (uint8) {
        return groupLetter[msg.sender];
    }

    //teste apenas
    function faseAtual() external view returns (string memory) {
        if (currentPhase == Phase.Initialization) {
            return "Initialization\n";
        }
        else if (currentPhase == Phase.Phase1) {
            return "Phase1\n";
        }
        else if (currentPhase == Phase.Phase2) {
            return "Phase2\n";

        }
        else if (currentPhase == Phase.Phase3) {
            return "Phase3\n";
        }
        else {
            return "Ended\n";
        }
    }

    function checkObjection(int256 _subject) internal returns (string memory, uint256) {
        uint8 letter;

        letter = groupLetter[msg.sender];
        require (letter > 0, "Invalid caller");
        letter--;
        require (groups[letter].currentObjection[uint(_subject  + 1)] >= 0, "No objection yet");
        buffer = checkObjectionTime(letter);
        return (groups[letter].objections[uint(groups[letter].currentObjection[uint(_subject  + 1)])].description,
        groups[letter].objections[uint(groups[letter].currentObjection[uint(_subject  + 1)])].endTime);
    }

    function checkPhase1() external onlyDuringPhase(Phase.Phase1) returns (string memory, uint256) {
        return checkObjection(-1);
    }

    function checkPhase2(int256 _subject) external onlyDuringPhase(Phase.Phase2) returns (string memory, uint256) {
        require(_subject > 0, "Escolha valores superiores a 1");
        return checkObjection(_subject);
    }

    function checkGroupsEndTime() external returns (uint256, uint256, uint256) {
        checkPhaseTransition();
        return (groups[0].phaseEndTime, groups[1].phaseEndTime, groups[2].phaseEndTime);
    }

    function checkObjectionTime(uint8 letter) internal returns (uint8) { //mudei 21/12
        uint256 index;

        index = uint(groups[letter].currentObjection[0]);
        // if (groups[letter].currentObjection[0] >= 0 &&
        // block.timestamp > groups[letter].objections[index].endTime &&
        // groups[letter].objections[index].objectionVote > 0) {
        //     groups[letter].objections[index].resolved = true;
        //     waiting[letter] = 1;
        //     return 1;
        // }
        if (groups[letter].currentObjection[0] >= 0 &&
        groups[letter].objections[index].objectionVote > 0) { //decidir o que ocorre em caso de < 0
            groups[letter].objections[index].resolved = 1;
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
            if (waiting[i] == 0 && block.timestamp > groups[i].phaseEndTime) {
                waiting[i] = 1;
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

    function checkWinningObjections2() external view onlyDuringPhase(Phase.Phase2) returns (string memory, string memory, string memory, string memory, string memory, string memory) {
        uint8 letter;

        letter = groupLetter[msg.sender];
        require (letter > 0, "Invalid caller");
        return (groups[0].objections[uint(groups[0].currentObjection[2])].description,
        groups[0].objections[uint(groups[0].currentObjection[3])].description,
        groups[1].objections[uint(groups[1].currentObjection[2])].description,
        groups[1].objections[uint(groups[1].currentObjection[3])].description,
        groups[2].objections[uint(groups[2].currentObjection[2])].description,
        groups[2].objections[uint(groups[2].currentObjection[3])].description);
    }

    function finalize() external onlyDuringPhase(Phase.Middle) returns (string memory) {
        if (block.timestamp < groups[3].phaseEndTime) {
            int8 checkSum;
            uint8 letter;
            uint256 index;

            letter = groupLetter[msg.sender];
            if (letter > 0) {
                letter--;
            }
            else {
                return "Invalid caller";
            }
            for (uint8 i = 1; i <= 3; i++) {
                index = uint(groups[letter].currentObjection[i]);
                checkSum += groups[letter].objections[i].resolved * objectionVote[letter][index][msg.sender];
            }
            if (checkSum == 3) {
                groups[3].members.push(msg.sender);
                groupLetter[msg.sender] = 4;
                voterCount_middle++;
                if (voterCount_middle == voterCount) {
                    phaseTransition();
                }
                return "Passed to final phase";
            }
            else {
                return "Your reward:";
            }
        }
        else {
            phaseTransition();
            return "Phase over";
        }
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
        voterCount++;
        if (voterCount == groupSize * 3) {
            for (uint8 i = 0; i < 3; i++) {
                for (uint j = 0; j <= 3; j++) {
                    groups[i].currentObjection.push(-1);
                }
            }
            phaseTransition();
        }
    }

    function phaseCorrection(uint8 increase) internal { //mudei 21/12
        for (uint8 i = 0; i < 3; i++) {
            groups[i].phaseStartTime = block.timestamp;
            groups[i].phaseEndTime += groups[i].phaseStartTime + increase * duration;
            waiting[i] = 0;
        }
    }

    function phaseTransition() internal { //mudei 21/12
        uint8 checkSum;

        if (currentPhase == Phase.Initialization) {
            phaseCorrection(1);
            currentPhase = Phase.Phase1;
            emit TransitionToPhase(Phase.Phase1);
        }
        else if (currentPhase == Phase.Phase1) {
            for (uint8 i = 0; i < 3; i++) {
                checkSum += checkObjectionTime(i);
            }
            if (checkSum == 3) {
                for (uint8 i = 0; i < 3; i++) {
                    groups[i].currentObjection[1] = groups[i].currentObjection[0];
                }
                phaseCorrection(2);
                currentPhase = Phase.Phase2;
                emit TransitionToPhase(Phase.Phase2);
            }
            else {
                currentPhase = Phase.Ended;
                emit TransitionToPhase(Phase.Ended);
                emit EvaluationCompleted("Approved");
            }
        }
        else if (currentPhase == Phase.Phase2) {
            for (uint8 i = 0; i < 7; i++) {
                groups[i].currentObjection.push(-1);        
            }
            groups[3].phaseStartTime = block.timestamp;
            groups[3].phaseEndTime += groups[3].phaseStartTime + duration;
            currentPhase = Phase.Middle;
            emit TransitionToPhase(Phase.Middle);
        }
        else if (currentPhase == Phase.Middle) {
            groups[3].phaseStartTime = block.timestamp;
            groups[3].phaseEndTime += groups[3].phaseStartTime + 3 * duration;
            currentPhase = Phase.Phase3;
            emit TransitionToPhase(Phase.Phase3);
        }
        else {
            currentPhase = Phase.Ended;
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
            buffer = checkObjectionTime(letter);
            index = uint(groups[letter].currentObjection[uint(_subject + 1)]); //atencao quanto ao 1
            // if (groups[letter].currentObjection[0] >= 0 && !(waiting[letter] == 0 &&
            // block.timestamp > groups[letter].objections[index].endTime)) {
            //     return "The current objection is still running";
            // }
            if (groups[letter].currentObjection[uint(_subject + 1)] >= 0 && !(waiting[letter] == 0)) {
                return "The current objection is still running";
            }
            groups[letter].objections.push(Objection({creator: msg.sender, description: _description,
            endTime: block.timestamp + duration / 5, startTime: block.timestamp, objectionVote: 0,
            subject: _subject, resolved: -1}));
            groups[letter].currentObjection[0]++;
            groups[letter].phaseEndTime += duration / 5;
            if (_subject > 0) {
                groups[letter].currentObjection[uint(_subject + 1)] = groups[letter].currentObjection[0];
            }
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
        require(_subject > 0, "Escolha valores superiores a 1");
        return raiseObjection(_description, _subject);
    }

    function raisePhase3(string memory _description, int256 _subject) external onlyDuringPhase(Phase.Phase2) returns (string memory) {
        require(_subject > 0, "Escolha valores superiores a 1");
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
            buffer = checkObjectionTime(letter);
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
        if (letter > 0) {
            letter--;
        }
        else {
            return "Invalid caller";
        }
        buffer = checkObjectionTime(letter);
        index = uint(groups[letter].currentObjection[uint(_subject + 1)]);
        if (groups[letter].currentObjection[uint(_subject + 1)] >= 0) {
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
        return "Succes";
    }

    function votePhase1(int8 _vote) external onlyDuringPhase(Phase.Phase1) returns (string memory) {
        return voteObjection(-1, _vote);
    }

    function votePhase2(int256 _subject, int8 _vote) external onlyDuringPhase(Phase.Phase2) returns (string memory) {
        require(_subject > 0, "Escolha valores superiores a 1");
        return voteObjection(_subject, _vote);
    }

    function votePhase3(int256 _subject, int8 _vote) external onlyDuringPhase(Phase.Phase2) returns (string memory) {
        require(_subject > 0, "Escolha valores superiores a 1");
        return voteObjection(_subject, _vote);
    }
}