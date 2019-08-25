#!/usr/bin/env ruby

require 'yaml'

def buildList( content, key, val )
  section = val[:header] || ""
  order   = val[:sortby] || :name
  val[:list].sort_by { |k| k[order] }.each do |i|
    section << val[:template] % i
  end
  return substitute("#{key}-section", content, section)
end
def substitute(tag,content,string)
  s = "<!-- %s --><!-- auto-populated -->\n%s<!-- \/%s -->" % [tag, string, tag]
  return content.gsub(/<!-- #{tag} -->(.*)<!-- \/#{tag} -->/im, s)
end
def replace(file_path, tag, content)
  string = File.open(file_path,'r').read()

  string = string.scan(/<!-- #{tag} -->(.*)<!-- \/#{tag} -->/imu).flatten.join("\n")
  return substitute(tag,content,string)
end
def getReferences(dir)
  # /\*.*?_\[.*?\)_.*?$/
  # * Hinderaker, Eric. _[Elusive Empires: Constructing Colonialism in the Ohio Valley, 1673-1800](https://amzn.to/2KGiuUR)_. 2003.
  references = []
  Dir["#{dir}/**/*.md"].each do |f|
    # puts f
    references += File.open(f).read().scan(/(\*.*?_\[.*?\)_.*?\n)/)
  end
  references
end

content = File.open('README.md','r').read()

# ============================================
## Building Section lists
sections = {
  "location" => {
    :list     => [],
    :sortby   => :name,
    :template => "* **[%{name}](%{filename}).** %{summary}\n",
    :header   => ""
  },
  "major-character" => {
    :list     => [],
    :sortby   => :name,
    :template => "* **[%{name}](%{filename})** (%{season})\n%{summary}\n",
    :header   => ""
  },
  "season" => {
    :list     => [],
    :sortby   => :order,
    :template => "| **[%{order}](%{filename})** | %{summary} |\n",
    :header   => "| # | Synopsis |\n| :-: | - |\n"
  },
  "trope" => {
    :list     => [],
    :sortby   => :name,
    :template => "* **[%{name}](%{filename}).** %{summary}\n",
    :header   => ""
  },
}

Dir.glob("./docs/**/*.md").each { |file|
  begin
    y = YAML.load_file(file)
    next if sections[y['type']].nil?
    sections[y['type']][:list] << {
      :name     => y['name'],
      :role     => y['role'],
      :order    => y['order'],
      :season    => y['season'],
      :summary  => y['summary'],
      :filename => file,
    } if y.is_a? Hash
  rescue
  end
}

sections.each do |key, val|
  content = buildList(content, key, val)
end

# ============================================
## Perform series of static string substitutions.
actions = {
  "series-outline"   => "docs/01-Overview/10-series-outline.md",
  "setting-overview" => "docs/02-Setting/00-overview.md",
  "format-overview"  => "docs/01-Overview/02-format.md",
  "concept-overview" => "docs/01-Overview/01-overview.md",
  "audience"         => "docs/01-Overview/03-audience.md",
}.each do |key, value|
  content = replace(value, key, content)
end

# ============================================
# Building Table of Contents
toc = ""
content.scan(/^##\s?(.*)\n/iu).flatten.each do |header|
  next if header == 'Contents'
  indent = ""
  header.gsub!(/#\s?+/) { indent += "  "; "" }
  anchor = header.downcase.gsub(/\W+/,'-').chomp('-')
  toc << "%s* [%s](#%s)\n" % [indent,header,anchor]
end
content = substitute("toc",content,toc)

# ============================================
# Building Table of References

references = getReferences("research") + getReferences("docs")
content = substitute(
  "references",
  content,
  references.uniq.sort.join("").gsub("-->",'').strip)

target = 'README.md'
# target = 'README-temp.md'

File.open(target,'w').write(content)
