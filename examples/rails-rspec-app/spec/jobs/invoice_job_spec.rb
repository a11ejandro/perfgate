# frozen_string_literal: true

# Illustrative job-spec workload (spec section 13.7): explicit in-process
# job execution, with per-example overrides of the default sample/warmup
# counts (spec section 9.3) for a more expensive workload. See the note
# in ../requests/checkout_spec.rb about this file's placeholder status.
RSpec.describe InvoiceJob, type: :job, perfgate: { samples: 5, warmup: 1 } do
  it "generates an invoice for a completed order" do
    order = create(:order, :completed, line_item_count: 50)

    Perfgate.measure { described_class.perform_now(order.id) }

    expect(order.reload.invoice).to be_present
  end
end
