class CreateRefunds < ActiveRecord::Migration[8.1]
  def change
    create_table :refunds do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, foreign_key: true  # admin who processed the refund
      t.string :stripe_refund_id              # Stripe refund ID (re_xxx)
      t.integer :amount_cents, null: false    # refund amount in cents
      t.string :reason                        # reason for refund
      t.string :status, default: 'pending'    # pending, succeeded, failed
      t.text :notes                           # admin notes
      t.jsonb :metadata, default: {}          # extra data (items refunded, etc.)
      t.timestamps
    end

    add_index :refunds, :stripe_refund_id, unique: true
    add_index :refunds, :status
  end
end
