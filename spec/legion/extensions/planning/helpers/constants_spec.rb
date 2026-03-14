# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Planning::Helpers::Constants do
  describe 'PLAN_STATUSES' do
    it 'is frozen' do
      expect(described_class::PLAN_STATUSES).to be_frozen
    end

    it 'contains 6 statuses' do
      expect(described_class::PLAN_STATUSES.size).to eq(6)
    end

    %i[forming active executing completed failed abandoned].each do |s|
      it "includes :#{s}" do
        expect(described_class::PLAN_STATUSES).to include(s)
      end
    end
  end

  describe 'STEP_STATUSES' do
    it 'is frozen' do
      expect(described_class::STEP_STATUSES).to be_frozen
    end

    it 'contains 6 statuses' do
      expect(described_class::STEP_STATUSES.size).to eq(6)
    end

    %i[pending active completed failed skipped blocked].each do |s|
      it "includes :#{s}" do
        expect(described_class::STEP_STATUSES).to include(s)
      end
    end
  end

  describe 'PRIORITIES' do
    it 'is frozen' do
      expect(described_class::PRIORITIES).to be_frozen
    end

    it 'has 4 levels' do
      expect(described_class::PRIORITIES.size).to eq(4)
    end

    it 'critical is the highest priority' do
      expect(described_class::PRIORITIES[:critical]).to eq(1.0)
    end

    it 'low is the lowest priority' do
      expect(described_class::PRIORITIES[:low]).to be < described_class::PRIORITIES[:medium]
    end

    it 'all values are between 0 and 1' do
      described_class::PRIORITIES.each_value do |v|
        expect(v).to be_between(0.0, 1.0)
      end
    end
  end

  describe 'scalar constants' do
    it 'MAX_PLANS is positive' do
      expect(described_class::MAX_PLANS).to be > 0
    end

    it 'MAX_STEPS_PER_PLAN is positive' do
      expect(described_class::MAX_STEPS_PER_PLAN).to be > 0
    end

    it 'MAX_CONTINGENCIES is positive' do
      expect(described_class::MAX_CONTINGENCIES).to be > 0
    end

    it 'REPLAN_LIMIT is positive' do
      expect(described_class::REPLAN_LIMIT).to be > 0
    end

    it 'STALE_PLAN_THRESHOLD is positive' do
      expect(described_class::STALE_PLAN_THRESHOLD).to be > 0
    end

    it 'COMPLETION_THRESHOLD is between 0 and 1' do
      expect(described_class::COMPLETION_THRESHOLD).to be_between(0.0, 1.0)
    end

    it 'PLANNING_HORIZON is positive' do
      expect(described_class::PLANNING_HORIZON).to be > 0
    end
  end
end
