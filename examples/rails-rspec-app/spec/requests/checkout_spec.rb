# frozen_string_literal: true

# Illustrative request-spec workload (spec sections 9.1 and 13.7). This
# file is not currently run by CI: examples/rails-rspec-app is a
# placeholder until a real Rails app is scaffolded (see the top-level
# README in this directory). It shows the intended shape of a
# request-spec workload once that app exists.
#
# `perfgate:` opts the example into measurement with the project's default
# samples/warmup/metrics and declares the assurance claim and owner.
# `Perfgate.measure`
# scopes SQL/allocation/GC collection to exactly the request under test,
# excluding sign-in, fixture setup, and response-body assertions.
RSpec.describe "Checkout", type: :request,
          perfgate: {
            claim: "Checkout latency and database work do not materially deteriorate",
            owner: "payments-platform@example.com"
          } do
  it "creates an order" do
    sign_in(create(:user))
    cart = create(:cart, :with_line_items)

    Perfgate.measure do
      post "/checkout", params: { cart_id: cart.id }
    end

    expect(response).to have_http_status(:created)
  end
end
