"""
Tests for BaseGovernancePowerStrategy.sol using the mock contract GovernancePowerStrategyMock.sol
"""

"""
def test_get_full_voting_power(setup_protocol, owner):
"""
#Testing `getFullVotingPower()`
"""
    #Setup
    governance_power_strategy_mock = setup_protocol["governance_power_strategy_mock"]
    delegation_token_a = setup_protocol["delegation_token_a"]
    delegation_token_b = setup_protocol["delegation_token_b"]
    # call `getFullVotingPower()`
    tx = governance_power_strategy_mock.getFullVotingPower(owner)
    # Validation
    assert tx == delegation_token_a.votingPower() + delegation_token_b.votingPower()



def test_get_full_proposition_power(setup_protocol, owner):
"""
#Testing `getFullPropositionPower()`
"""
    #Setup
    governance_power_strategy_mock = setup_protocol["governance_power_strategy_mock"]
    delegation_token_a = setup_protocol["delegation_token_a"]
    delegation_token_b = setup_protocol["delegation_token_b"]
    # call `getFullPropositionPower()`
    tx = governance_power_strategy_mock.getFullPropositionPower(owner)
    # Validation
    assert tx == delegation_token_a.propositionPower() + delegation_token_b.propositionPower()


"""
