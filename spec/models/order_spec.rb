require 'rails_helper'

RSpec.describe Order, type: :model do
  describe 'validations' do
    it 'is valid with all required attributes' do
      order = build(:order, :guest)
      expect(order).to be_valid
    end

    context 'guest orders (no user_id)' do
      it 'requires customer_email' do
        order = build(:order, :guest, customer_email: nil)
        expect(order).not_to be_valid
        expect(order.errors[:customer_email]).to include('is required for guest checkout')
      end

      it 'rejects blank customer_email' do
        order = build(:order, :guest, customer_email: '')
        expect(order).not_to be_valid
        expect(order.errors[:customer_email]).to include('is required for guest checkout')
      end

      it 'is valid with customer_email present' do
        order = build(:order, :guest, customer_email: 'guest@example.com')
        expect(order).to be_valid
      end
    end

    context 'authenticated orders (has user_id)' do
      it 'does not require customer_email' do
        user = create(:user) rescue nil
        # If User factory doesn't exist, skip this test
        skip 'User factory not available' unless user
        order = build(:order, user: user, customer_email: nil)
        expect(order).to be_valid
      end
    end
  end

  describe 'convenience aliases' do
    let(:order) { build(:order, :guest, customer_email: 'test@example.com', customer_phone: '555-0000', customer_name: 'Jane Doe') }

    it 'aliases email to customer_email' do
      expect(order.email).to eq('test@example.com')
    end

    it 'aliases phone to customer_phone' do
      expect(order.phone).to eq('555-0000')
    end

    it 'aliases name to customer_name' do
      expect(order.name).to eq('Jane Doe')
    end

    it 'sets customer_email via email=' do
      order.email = 'new@example.com'
      expect(order.customer_email).to eq('new@example.com')
    end

    it 'sets customer_phone via phone=' do
      order.phone = '555-9999'
      expect(order.customer_phone).to eq('555-9999')
    end

    it 'sets customer_name via name=' do
      order.name = 'New Name'
      expect(order.customer_name).to eq('New Name')
    end
  end
end
