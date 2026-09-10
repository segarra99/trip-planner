# frozen_string_literal: true

class PagesController < ApplicationController
  def roadtrip; end

  def architecture
    architecture_path = Rails.root.join('docs', 'ARCHITECTURE.md')
    @architecture_content = File.read(architecture_path)
    @architecture_html = render_markdown(@architecture_content)
  end

  def deployment
    deployment_path = Rails.root.join('docs', 'DEPLOYMENT.md')
    @deployment_content = File.read(deployment_path)
    @deployment_html = render_markdown(@deployment_content)
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
