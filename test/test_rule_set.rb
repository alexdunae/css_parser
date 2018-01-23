require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require "set"

# Test cases for parsing CSS blocks
class RuleSetTests < Minitest::Test
  include CssParser

  def setup
    @cp = Parser.new
  end

  def test_setting_property_values
    rs = RuleSet.new(nil, nil)

    rs['background-color'] = 'red'
    assert_equal('red;', rs['background-color'])

    rs['background-color'] = 'blue !important;'
    assert_equal('blue !important;', rs['background-color'])
  end

  def test_getting_property_values
    rs = RuleSet.new('#content p, a', 'color: #fff;')
    assert_equal('#ffffff;', rs['color'])
  end

  def test_getting_property_value_ignoring_case
    rs = RuleSet.new('#content p, a', 'color: #fff;')
    assert_equal('#ffffff;', rs['  ColoR '])
  end

  def test_each_selector
    expected = [
      {:selector => "#content p", :declarations => "color: #ffffff;", :specificity => 101},
      {:selector => "a", :declarations => "color: #ffffff;", :specificity => 1}
    ]

    actual = []
    rs = RuleSet.new('#content p, a', 'color: #ffffff;')
    rs.each_selector do |sel, decs, spec|
      actual << {:selector => sel, :declarations => decs, :specificity => spec}
    end

    assert_equal(expected, actual)
  end

  def test_each_declaration
    expected = Set.new([
      {:property => 'margin', :value => '1px -0.25em', :is_important => false},
      {:property => 'background', :value => 'white none no-repeat', :is_important => true},
      {:property => 'color', :value => '#ffffff', :is_important => false}
    ])

    actual = Set.new
    rs = RuleSet.new(nil, 'color: #ffffff; Background: white none no-repeat !important; margin: 1px -0.25em;')
    rs.each_declaration do |prop, val, imp|
      actual << {:property => prop, :value => val, :is_important => imp}
    end

    assert_equal(expected, actual)
  end

  def test_each_declaration_respects_order
    css_fragment = "margin: 0; padding: 20px; margin-bottom: 28px;"
    rs           = RuleSet.new(nil, css_fragment)
    expected     = %w(margin padding margin-bottom)
    actual       = []
    rs.each_declaration { |prop, val, imp| actual << prop }
    assert_equal(expected, actual)
  end

  def test_each_declaration_containing_semicolons
    rs = RuleSet.new(nil, "background-image: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABwAAAAiCAMAAAB7);" +
      "background-repeat: no-repeat")
    assert_equal('url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABwAAAAiCAMAAAB7);', rs['background-image'])
    assert_equal('no-repeat;', rs['background-repeat'])
  end

  def test_selector_sanitization
    selectors = "h1, h2,\nh3 "
    rs = RuleSet.new(selectors, "color: #fff;")
    assert rs.selectors.member?("h3")
  end

  def test_multiple_selectors_to_s
    selectors = "#content p, a"
    rs = RuleSet.new(selectors, "color: #fff;")
    assert_match(/^\s*#content p,\s*a\s*\{/, rs.to_s)
  end

  def test_declarations_to_s
    declarations = 'color: #ffffff; font-weight: bold;'
    rs = RuleSet.new('#content p, a', declarations)
    assert_equal(declarations.split(' ').sort, rs.declarations_to_s.split(' ').sort)
  end

  def test_important_declarations_to_s
    declarations = 'color: #ffffff; font-weight: bold !important;'
    rs = RuleSet.new('#content p, a', declarations)
    assert_equal(declarations.split(' ').sort, rs.declarations_to_s.split(' ').sort)
  end

  def test_overriding_specificity
    rs = RuleSet.new('#content p, a', 'color: white', 1000)
    rs.each_selector do |sel, decs, spec|
      assert_equal 1000, spec
    end
  end

  def test_not_raised_issue68
    ok = true
    begin
      RuleSet.new('td', 'border-top: 5px solid; border-color: #fffff0;')
    rescue
      ok = false
    end
    assert_equal true, ok
  end

  def test_ensure_six_digit_hex_value
    rs = RuleSet.new(nil, nil)
    # Test a non-hex value
    value = '12px'
    assert_equal value, rs.ensure_six_digit_hex_value(value)
    # Test a 2-digit hex (not valid)
    value = '#ab'
    assert_equal value, rs.ensure_six_digit_hex_value(value)
    # Test a 3-digit hex
    value = '#abc'
    assert_equal '#aabbcc', rs.ensure_six_digit_hex_value(value)
    # Test a 6-digit hex
    value = '#abcdef'
    assert_equal value, rs.ensure_six_digit_hex_value(value)
  end
end
