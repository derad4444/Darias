// タグと5軸のマッピング定義
// direction: +1 = 正方向、-1 = 負方向

const TAG_AXIS_MAP = {
  social_reference:     { energy: +1 },
  solo_preference:      { energy: -1 },
  group_activity:       { energy: +1, relationship: +1 },
  initiating:           { energy: +1 },
  quiet_environment:    { energy: -1 },
  planning_language:    { lifestyle: +1 },
  spontaneous_language: { lifestyle: -1 },
  goal_oriented:        { lifestyle: +1 },
  emotional_expression: { judgment: -1, processing: -1 },
  logical_reasoning:    { judgment: +1, processing: +1 },
  intuitive_decision:   { judgment: -1, processing: -1 },
  data_driven:          { judgment: +1, processing: +1 },
  cooperative_language: { relationship: +1 },
  independent_stance:   { relationship: -1 },
  self_paced:           { relationship: -1 },
  change_seeking:       { lifestyle: -1, processing: -1 },
  worry_anxiety:        { judgment: -1 },
};

const AXES = ['energy', 'judgment', 'relationship', 'lifestyle', 'processing'];

module.exports = { TAG_AXIS_MAP, AXES };
