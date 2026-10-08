-- The first shift, as saved progress. A player's Onboarding.TutorialStep is how
-- many of these steps they have completed, so leaving mid-tutorial resumes where
-- they were (it used to be skipped entirely, with its bonuses). Each step is
-- logged once to the Onboarding funnel, in order.

local Tutorial = {}

Tutorial.Steps = {
    "Arrived", -- 1: the line started for the first time
    "FirstCatch", -- 2: first defect rejected (pays FirstCatchReward)
    "FirstUpgrade", -- 3: first upgrade bought
    "FirstShiftRush", -- 4: the first-shift rush started
    "ShiftComplete", -- 5: the first-shift rush ended (pays CompletionBonus)
}

Tutorial.FirstCatchReward = 25
Tutorial.CompletionBonus = 100

function Tutorial.StepIndex(stepName)
    return table.find(Tutorial.Steps, stepName)
end

function Tutorial.IsComplete(tutorialStep)
    return tutorialStep >= #Tutorial.Steps
end

return Tutorial
