require 'json'
require 'fileutils'
require './_plugins/notebook'
require './_plugins/gtn'

def json_boxify(h, page)
  h['cells'].each do |cell|
    # If it's a list, loop
    if cell['source'].is_a? Array
      cell['source'].each do |line|
        line.gsub!(%r{<(?<boxclass>#{Gtn::Boxify.box_classes})-title( ?(?<noprefix>noprefix))>(?<title>.*?)</\s*\k<boxclass>-title\s*>}) do
          m = Regexp.last_match
          box_type = m[:boxclass]
          title = m[:title]
          noprefix = m[:noprefix]
          _, box = Gtn::Boxify.generate_title(box_type, title, lang, page.path, noprefix: noprefix)
          box
        end
      end
    else
      cell['source'].gsub!(%r{<(?<boxclass>#{Gtn::Boxify.box_classes})-title(?<noprefix>\s+noprefix)?>(?<title>.*?)</\s*\k<boxclass>-title\s*>}) do
        m = Regexp.last_match
        box_type = m[:boxclass]
        title = m[:title]
        noprefix = m[:noprefix]
        _, box = Gtn::Boxify.generate_title(box_type, title, 'en', page.path, noprefix: noprefix)
        box
      end
    end
  end
  h
end

Jekyll::Hooks.register :site, :pre_render do |site|
  puts '[GTN/Notebooks] Rendering'

  # For every tutorial with the 'notebook' key in the page data
  site.pages.select { |page| GTNNotebooks.notebook_filter(page.data) }.each do |page|
    # We get the path to the tutorial source
    dir = File.dirname(File.join('.', page.url))
    fn = File.join('.', page.url).sub(/html$/, 'md')
    notebook_language = page.data['notebook'].fetch('language', 'python')

    # Tag our source page
    page.data['tags'] = [] unless page.data.key? 'tags'
    page.data['tags'].push('jupyter-notebook')

    puts "[GTN/Notebooks] Rendering #{notebook_language} #{fn}"
    last_modified = Gtn::ModificationTimes.obtain_time(page.path)
    notebook = GTNNotebooks.render_jupyter_notebook(page.data, page.content, page.url, last_modified,
                                                    notebook_language, site, dir)

    topic_id = dir.split('/')[-3]
    tutorial_id = dir.split('/')[-1]
    with_solutions = notebook.clone

    with_solutions['cells'] = with_solutions['cells'].map do |cell|
      if cell.fetch('cell_type') == 'markdown' && (cell['source'].is_a? String)
        m = cell['source'].match(/<blockquote class="solution"[^>]*>/)
        if m
          cell['source'].gsub!(/<blockquote class="solution"[^>]*>/,
                               '<br/><details style="border: 2px solid #B8C3EA; margin: 1em 0.2em;' \
                               'padding: 0.5em; cursor: pointer;"><summary>👁 View solution</summary>')

          idx = m.begin(0)
          q = cell['source'][0..idx]
          w = cell['source'][idx + 1..]
          e = w.index('</blockquote>')
          r = "#{w[0..e - 1]}</details>#{w[e + 13..]}"

          cell['source'] = q + r
        end
      end
      cell
    end

    # Write it out!
    ipynb_path = File.join(dir, "#{topic_id}-#{tutorial_id}.ipynb")
    File.write(ipynb_path, JSON.pretty_generate(json_boxify(with_solutions, page)))
    # page2 = PageWithoutAFile.new(site, '', dir, "#{topic_id}-#{tutorial_id}.ipynb")
    # page2.content = JSON.pretty_generate(with_solutions)
    # page2.data['layout'] = nil
    # page2.data['citation_target'] = 'jupyter'
    # site.pages << page2

    # Create a no-solutions version:
    no_solutions = notebook.clone

    no_solutions['cells'] = no_solutions['cells'].map do |cell|
      if cell.fetch('cell_type') == 'markdown' && (cell['source'].is_a? String)
        cell['source'].gsub!(/<blockquote class="solution"[^>]*>/,
                             '<blockquote class="solution" style="display:none">')
      end
      cell
    end

    ipynb_path2 = File.join(dir, "#{topic_id}-#{tutorial_id}-course.ipynb")
    File.write(ipynb_path2, JSON.pretty_generate(json_boxify(no_solutions, page)))
    # page2 = PageWithoutAFile.new(site, '', dir, "#{topic_id}-#{tutorial_id}-course.ipynb")
    # page2.content = JSON.pretty_generate(no_solutions)
    # page2.data['layout'] = nil
    # page2.data['citation_target'] = 'jupyter'
    # site.pages << page2
  end
end
