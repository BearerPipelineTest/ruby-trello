require 'spec_helper'

module Trello
  describe Label do
    include Helpers

    let(:label) { client.find(:label, 'abcdef123456789123456789') }
    let(:client) { Client.new }

    before do
      allow(client)
        .to receive(:get)
        .with("/labels/abcdef123456789123456789", {})
        .and_return JSON.generate(label_details.first)
    end

    context "finding" do
      let(:client) { Trello.client }

      it "delegates to Trello.client#find" do
        expect(client)
          .to receive(:find)
          .with('label', 'abcdef123456789123456789', {})

        Label.find('abcdef123456789123456789')
      end

      it "is equivalent to client#find" do
        expect(Label.find('abcdef123456789123456789')).to eq(label)
      end
    end

    context "creating" do
      let(:client) { Trello.client }

      it "creates a new record" do
        expect(Label.new(label_details.first)).to be_valid
      end

      it "initializes all fields from response-like formatted hash" do
        details = label_details.first
        label = Label.new(details)
        expect(label.color).to    eq details['color']
        expect(label.name).to     eq details['name']
        expect(label.id).to       eq details['id']
        expect(label.board_id).to eq details['idBoard']
      end

      it "initializes required fields from options-like formatted hash" do
        details = label_options
        label = Label.new(details)
        expect(label.name).to     eq details[:name]
        expect(label.board_id).to eq details[:board_id]
        expect(label.color).to    eq details[:color]
      end

      it 'must not be valid if not given a name' do
        expect(Label.new('idBoard' => lists_details.first['board_id'])).to_not be_valid
      end

      it 'must not be valid if not given a board id' do
        expect(Label.new('name' => lists_details.first['name'])).to_not be_valid
      end

      it 'creates a new record and saves it on Trello', refactor: true do
        payload = {
          name: 'Test Label',
          board_id: 'abcdef123456789123456789',
        }

        result = JSON.generate(cards_details.first.merge(payload.merge(idBoard: boards_details.first['id'])))

        expected_payload = {'name' => 'Test Label', 'color' => 'yellow', 'idBoard' => 'abcdef123456789123456789' }

        expect(Label.client)
          .to receive(:post)
          .with('/labels', expected_payload)
          .and_return result

        params = label_details.first.merge(payload.merge(board_id: boards_details.first['id']))
        params.delete('id')
        label = Label.create params

        expect(label).to be_a Label
      end
    end

    context "updating" do
      it "updating name does a put on the correct resource with the correct value" do
        expected_new_name = "xxx"

        payload = {
          'name' => expected_new_name,
        }

        expect(client)
          .to receive(:put)
          .once
          .with("/labels/abcdef123456789123456789", payload)
          .and_return({
            "id" => "abcdef123456789123456789",
            "idBoard" => "5e70f5bed3f34a49e2f11409",
            "name" => "xxx",
            "color" => "purple"
          }.to_json)

        label.name = expected_new_name
        label.save
      end

      it "updating color does a put on the correct resource with the correct value" do
        expected_new_color = "purple"

        payload = {
          'color' => expected_new_color
        }

        expect(client)
          .to receive(:put)
          .once
          .with("/labels/abcdef123456789123456789", payload)
          .and_return({
            "id" => "abcdef123456789123456789",
            "idBoard" => "5e70f5bed3f34a49e2f11409",
            "name" => "",
            "color" => "purple"
          }.to_json)

        label.color = expected_new_color
        label.save
      end

      it "can update with any valid color" do
        %w(green yellow orange red purple blue sky lime pink black).each do |color|
          allow(client)
            .to receive(:put)
            .with("/labels/abcdef123456789123456789", {'color' => color})
            .and_return({
              "id" => "abcdef123456789123456789",
              "idBoard" => "5e70f5bed3f34a49e2f11409",
              "name" => "",
              "color" => color
            }.to_json)

          label.color = color
          label.save
          expect(label.errors).to be_empty
        end
      end
    end

    context "deleting" do
      it "deletes the label" do
        expect(client)
          .to receive(:delete)
          .with("/labels/#{label.id}")

        label.delete
      end
    end

    context "fields" do
      it "gets its id" do
        expect(label.id).to_not be_nil
      end

      it "gets its name" do
        expect(label.name).to_not be_nil
      end

      it "gets its color" do
        expect(label.color).to_not be_nil
      end
    end

    context "boards" do
      it "has a board" do
        expect(client)
          .to receive(:get)
          .with("/boards/abcdef123456789123456789", {})
          .and_return JSON.generate(boards_details.first)

        expect(label.board).to_not be_nil
      end
    end

    describe "#update_fields" do
      it "does not set any fields when the fields argument is empty" do
        expected = {
          'id' => 'id',
          'name' => 'name',
          'color' => 'color',
          'idBoard' => 'board_id'
        }

        label = Label.new(expected)

        label.update_fields({})

        expected.each do |key, value|
          expect(label.send(value)).to eq expected[key]
        end
      end
    end

    describe '#update_fields' do
      let(:label_detail) {{
        'id' => 'id',
        'name' => 'name',
        'color' => 'color',
        'idBoard' => 'board_id'
      }}
      let(:label) { Label.new(label_detail) }

      context 'when the fields argument is empty' do
        let(:fields) { {} }

        it 'card does not set any fields' do
          label.update_fields(fields)

          expect(label.id).to eq label_detail['id']
          expect(label.name).to eq label_detail['name']
          expect(label.color).to eq label_detail['color']
          expect(label.board_id).to eq label_detail['idBoard']
        end
      end

      context 'when the fields argument has at least one field' do
        context 'and the field does changed' do
          let(:fields) { { name: 'Awesome Name' } }

          it 'label does set the changed fields' do
            label.update_fields(fields)

            expect(label.name).to eq('Awesome Name')
          end

          it 'label has been mark as changed' do
            label.update_fields(fields)

            expect(label.changed?).to be_truthy
          end
        end

        context "and the field doesn't changed" do
          let(:fields) { { name: label_detail['name'] } }

          it "label attributes doesn't changed" do
            label.update_fields(fields)

            expect(label.name).to eq(label_detail['name'])
          end

          it "label hasn't been mark as changed" do
            label.update_fields(fields)

            expect(label.changed?).to be_falsy
          end
        end

        context "and the field isn't a correct attributes of the label" do
          let(:fields) { { abc: 'abc' } }

          it "label attributes doesn't changed" do
            label.update_fields(fields)

            expect(label.id).to eq label_detail['id']
            expect(label.name).to eq label_detail['name']
            expect(label.color).to eq label_detail['color']
            expect(label.board_id).to eq label_detail['idBoard']
          end

          it "label hasn't been mark as changed" do
            label.update_fields(fields)

            expect(label.changed?).to be_falsy
          end
        end
      end
    end
  end
end
