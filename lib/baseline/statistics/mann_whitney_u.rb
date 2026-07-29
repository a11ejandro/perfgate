# frozen_string_literal: true

module Baseline
  module Statistics
    # One-sided Mann-Whitney U test: estimates how likely it is that the
    # candidate distribution is drawn from a "worse" (larger-valued)
    # population than the baseline distribution, without assuming
    # normality (spec section 16.3). Uses a normal approximation with a
    # tie correction, adapted from the Milestone 0 spike
    # (spikes/regression_injection.rb) that validated this approach
    # against a seeded +20% duration regression.
    #
    # Baseline never surfaces this p-value directly to users (spec
    # 16.3: "do not expose p-values alone as user-facing proof") -- it is
    # combined with a practical-significance threshold by
    # Comparison::MetricDecision.
    module MannWhitneyU
      module_function

      # Returns p, the probability of observing rank sums this extreme
      # (or more) under the null hypothesis of no difference, tested
      # against the one-sided alternative that `candidate` tends to be
      # larger than `baseline`. Smaller p is stronger evidence the
      # candidate is worse.
      def one_sided_p(baseline, candidate)
        return 1.0 if baseline.empty? || candidate.empty?

        z = z_score(baseline, candidate)
        return 0.5 if z.nil?

        0.5 * Math.erfc(z / Math.sqrt(2))
      end

      # Standardized U statistic for the candidate sample, or nil when the
      # null distribution has zero variance (e.g. every sample tied).
      def z_score(baseline, candidate)
        n1 = baseline.size
        n2 = candidate.size
        u_candidate = candidate_rank_sum(baseline, candidate) - (n2 * (n2 + 1) / 2.0)
        std_u = standard_deviation_u(n1, n2)
        return nil if std_u.zero?

        (u_candidate - (n1 * n2 / 2.0)) / std_u
      end

      def standard_deviation_u(baseline_size, candidate_size)
        Math.sqrt(baseline_size * candidate_size * (baseline_size + candidate_size + 1) / 12.0)
      end

      def candidate_rank_sum(baseline, candidate)
        ranks = rank(baseline.map { |v| [v, :baseline] } + candidate.map { |v| [v, :candidate] })
        ranks.each_index.sum { |i| ranks[i][1] == :candidate ? ranks[i][2] : 0 }
      end

      # Assigns tied (averaged) ranks to a list of [value, label] pairs,
      # returning [value, label, rank] triples sorted by value.
      def rank(pairs)
        sorted = pairs.sort_by { |value, _label| value }
        ranked = Array.new(sorted.size)

        index = 0
        index = assign_tie_group(sorted, ranked, index) while index < sorted.size

        ranked
      end

      # Finds the run of tied values starting at start_index, assigns
      # them all the same averaged rank, and returns the index just past
      # the run.
      def assign_tie_group(sorted, ranked, start_index)
        end_index = tie_group_end(sorted, start_index)
        average_rank = ((start_index + 1) + (end_index + 1)) / 2.0
        (start_index..end_index).each { |k| ranked[k] = sorted[k] + [average_rank] }
        end_index + 1
      end

      def tie_group_end(sorted, start_index)
        end_index = start_index
        end_index += 1 while end_index + 1 < sorted.size && sorted[end_index + 1][0] == sorted[start_index][0]
        end_index
      end
    end
  end
end
