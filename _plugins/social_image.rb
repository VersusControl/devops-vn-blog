# frozen_string_literal: true

# Social preview images (og:image, twitter:image, JSON-LD image).
#
# Two problems this fixes:
#
# 1. Facebook, LinkedIn, X, and Zalo do not show SVG files in link previews.
#    Most covers are SVG, so platforms ignored og:image and picked another image
#    from the page instead, usually the author avatar. For every SVG share image,
#    this plugin uses the PNG next to it (cover.svg -> cover.png). The page itself
#    still shows the SVG. Create the PNGs with scripts/build-social-images.sh.
#
# 2. Series pages keep their cover in `cover:`, which jekyll-seo-tag ignores, so
#    they had no og:image at all. When a page has `cover:` and no `image:`, the
#    cover becomes its share image.
#
# 3. Pages with no image at all (home, /series/, /topics/, /tags/, about) get the
#    site-wide image set by `social_image` in _config.yml. It is added to the meta
#    tags only, so a page never displays it.

module SocialImage
  module_function

  # Series pages: use `cover` as the SEO image. page.html renders `page.cover`,
  # so setting `image` changes only the meta tags.
  def use_cover_as_image(page, payload)
    cover = page.data["cover"]
    return unless cover && !page.data["image"]

    # Jekyll copies a page's data into the render payload before this hook
    # runs, so set the value there as well as on the page.
    page.data["image"] = cover
    payload["page"]["image"] = cover if payload && payload["page"]
  end

  def rewrite(item)
    return unless item.output_ext == ".html" && item.output
    return add_default_image(item) unless item.output.include?('<meta property="og:image"')

    svg_url = item.output[/<meta property="og:image" content="([^"]+\.svg)"/, 1]
    return unless svg_url

    site = item.site
    site_url = "#{site.config["url"]}#{site.config["baseurl"]}"
    svg_path = svg_url.delete_prefix(site_url)
    png_path = svg_path.sub(/\.svg\z/, ".png")
    png_file = File.join(site.source, png_path)

    unless File.exist?(png_file)
      Jekyll.logger.warn "Social image:",
                         "#{png_path} is missing, so #{item.url} shares an SVG that " \
                         "social sites ignore. Run scripts/build-social-images.sh."
      return
    end

    png_url = "#{site_url}#{png_path}"
    # The page body links images with relative URLs, so replacing the absolute
    # URL changes only the meta tags and the JSON-LD block.
    output = item.output.gsub(svg_url, png_url)

    width, height = png_size(png_file)
    if width
      size_tags = %(<meta property="og:image:width" content="#{width}" />\n) +
                  %(<meta property="og:image:height" content="#{height}" />\n)
      output = output.sub(%r{(<meta property="og:image" content="#{Regexp.escape(png_url)}" />\n?)},
                          "\\1#{size_tags}")
    end

    item.output = output
  end

  def add_default_image(item)
    site = item.site
    path = site.config["social_image"]
    return unless path && item.output.include?("</title>")

    file = File.join(site.source, path)
    unless File.exist?(file)
      Jekyll.logger.warn "Social image:", "social_image #{path} in _config.yml does not exist."
      return
    end

    url = "#{site.config["url"]}#{site.config["baseurl"]}#{path}"
    width, height = png_size(file)
    tags = %(<meta property="og:image" content="#{url}" />\n)
    tags += %(<meta property="og:image:width" content="#{width}" />\n<meta property="og:image:height" content="#{height}" />\n) if width
    tags += %(<meta name="twitter:image" content="#{url}" />\n)

    output = item.output.sub(%(<meta name="twitter:card" content="summary" />),
                             %(<meta name="twitter:card" content="summary_large_image" />))
    item.output = output.sub("</title>", "</title>\n#{tags}")
  end

  # Read width and height from the PNG header (IHDR chunk).
  def png_size(file)
    header = File.binread(file, 24)
    return unless header&.start_with?("\x89PNG".b)

    header[16, 8].unpack("NN")
  end
end

Jekyll::Hooks.register :pages, :pre_render do |page, payload|
  SocialImage.use_cover_as_image(page, payload)
end

Jekyll::Hooks.register [:pages, :documents], :post_render do |item|
  SocialImage.rewrite(item)
end
