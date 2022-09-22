// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Suga.sol";

contract AntBosses is Initializable, AccessControlUpgradeable {
    bytes32 public constant ANT_CONTRACTS_ROLE = keccak256("ANT_CONTRACTS_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    address public SUGA_CONTRACT;
    address public AVALANT_CONTRACT;

    struct Boss {
        uint id;
        uint totalLife;
        uint currentLife;
        uint colonyStage;
        string name;
        uint numberOfFighters; // easier to get than .length
    }

    uint public numberOfBosses;
    mapping(uint => Boss) public bosses;
    mapping(uint => uint[]) public stageToBosses;
    mapping(uint => uint[]) public bossFighters;
    mapping(uint => uint[]) public damagesGivenToBoss;
    mapping(uint => uint[3]) public bossMvps;
    mapping(uint => mapping(uint => uint)) public antIndexInBossDamages;
    mapping(uint => mapping(uint => bool)) public hasHitBoss;

    // <Events>
    event BossCreated(uint id, string name, uint colonyStage, uint totalLife);
    event BossHit(uint bossId, uint antId, uint damage);
    event BossDied(uint bossId);
    // </Events>

    // VERSION 1.1
    uint public damageRatio;

    function initialize(address _avalantContrat) initializer public {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        AVALANT_CONTRACT = _avalantContrat;
    }

    function createBoss(uint _life, uint _colonyStage, string memory _name) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Boss storage boss = bosses[numberOfBosses];
        boss.id = numberOfBosses;
        boss.totalLife = _life;
        boss.currentLife = _life;
        boss.colonyStage = _colonyStage;
        boss.name = _name;
        bossMvps[numberOfBosses] = [10001, 10001, 10001];
        boss.numberOfFighters = 0;
        stageToBosses[boss.colonyStage].push(numberOfBosses);
        numberOfBosses += 1;
        emit BossCreated(boss.id, boss.name, boss.colonyStage, boss.totalLife);
    }

    // damageRatio is 10 for no change, 20 for double damage.
    function getRatio(uint _antId) public view returns (uint) {
        Avalant a = Avalant(AVALANT_CONTRACT);
        uint antRarity = a.antRarity(_antId);
        uint8[7] memory rarityToRatio = [10, 11, 12, 13, 14, 15, 16];
        return damageRatio * rarityToRatio[antRarity];
    }

    function _updateMvp(uint _bossId, uint _antId) internal {
        Boss storage boss = bosses[_bossId];
        if (boss.numberOfFighters == 1) {
            bossMvps[_bossId][0] = _antId;
            return;
        }
        uint bestAnt = bossMvps[_bossId][0];
        uint secondBestAnt = bossMvps[_bossId][1];
        uint thirdBestAnt = bossMvps[_bossId][2];

        if (bestAnt == _antId) {
            return;
        }

        if (damagesGivenToBoss[_bossId][antIndexInBossDamages[_bossId][_antId]] > damagesGivenToBoss[_bossId][antIndexInBossDamages[_bossId][bestAnt]]) {
            bossMvps[_bossId][0] = _antId;
            bossMvps[_bossId][1] = bestAnt;
            bossMvps[_bossId][2] = secondBestAnt == _antId ? thirdBestAnt : secondBestAnt;
        } else if (boss.numberOfFighters == 2 || damagesGivenToBoss[_bossId][antIndexInBossDamages[_bossId][_antId]] > damagesGivenToBoss[_bossId][antIndexInBossDamages[_bossId][secondBestAnt]]) {
            bossMvps[_bossId][1] = _antId;
            bossMvps[_bossId][2] = secondBestAnt;
        } else if (boss.numberOfFighters == 3 || damagesGivenToBoss[_bossId][antIndexInBossDamages[_bossId][_antId]] > damagesGivenToBoss[_bossId][antIndexInBossDamages[_bossId][thirdBestAnt]]) {
            if (secondBestAnt == _antId) {
                return;
            }
            bossMvps[_bossId][2] = _antId;
        }
    }

    function hitBoss(uint _damage, uint _antId, uint _bossId) external {
        Boss storage boss = bosses[_bossId];
        Avalant a = Avalant(AVALANT_CONTRACT);
        (,,uint colonyStage,,) = a.allAvalants(_antId);
        require(colonyStage == boss.colonyStage, "Boss not in range of ant");
        require(boss.currentLife > 0, "Boss is already dead");
        require(a.ownerOf(_antId) == msg.sender, "Not your ant");
        Suga s = Suga(SUGA_CONTRACT);

        uint ratio = getRatio(_antId);
        uint trueDamage = _damage * ratio / 100;

        if (trueDamage < boss.currentLife) {
            boss.currentLife -= trueDamage;
            s.burn(msg.sender, _damage);
        } else {
            trueDamage = boss.currentLife;
            s.burn(msg.sender, boss.currentLife / ratio * 100);
            boss.currentLife = 0;
        }

        // first hit of this ant
        if (hasHitBoss[_bossId][_antId] == false) {
            antIndexInBossDamages[_bossId][_antId] = boss.numberOfFighters;
            damagesGivenToBoss[_bossId].push(trueDamage);
            bossFighters[_bossId].push(_antId);
            boss.numberOfFighters += 1;
            hasHitBoss[_bossId][_antId] = true;
        } else {
            // update damages
            uint index = antIndexInBossDamages[_bossId][_antId];
            damagesGivenToBoss[_bossId][index] += trueDamage;
        }
        _updateMvp(_bossId, _antId);
        emit BossHit(_bossId, _antId, trueDamage);
        if (boss.currentLife == 0) {
            emit BossDied(_bossId);
        }
    }

    function isBossAliveAtStage(uint _stage) public view returns (bool) {
        if (stageToBosses[_stage].length == 0) {
            return false;
        }
        bool res = false;
        for (uint i = 0; i < stageToBosses[_stage].length; i++) {
            if (bosses[stageToBosses[_stage][i]].currentLife > 0) {
                res = true;
            }
        }
        return res;
    }

    // <AdminStuff>
    function setContractAddress(address _sugaAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ANT_CONTRACTS_ROLE, _sugaAddress);

        SUGA_CONTRACT = _sugaAddress;
    }

    function setRatio(uint _ratio) external onlyRole(DEFAULT_ADMIN_ROLE) {
        damageRatio = _ratio;
    }
    // </AdminStuff>
}