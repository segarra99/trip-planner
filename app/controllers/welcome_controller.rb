# frozen_string_literal: true

class WelcomeController < ActionController::Base
  layout "application"

  def index
    readme_path = Rails.root.join("README.md")
    @readme_content = File.read(readme_path)
    @readme_html = render_markdown(@readme_content)
  end

  private

  def render_markdown(content)
    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      fenced_code_blocks: true
    )
    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true
    )
    markdown.render(content).html_safe
  end
end
