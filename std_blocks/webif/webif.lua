local ffi=require"ffi"
local u5c=require"u5c"

local safe_ts = u5c.safe_tostr

-- Configuration
num_type_cols=2

--- define mongoose request info
ffi.cdef[[
struct mg_request_info {
  const char *request_method; // "GET", "POST", etc
  const char *uri;            // URL-decoded URI
  const char *http_version;   // E.g. "1.0", "1.1"
  const char *query_string;   // URL part after '?', not including '?', or NULL
  const char *remote_user;    // Authenticated user, or NULL if no auth used
  long remote_ip;             // Client's IP address
  int remote_port;            // Client's port
  int is_ssl;                 // 1 if SSL-ed, 0 if not
  void *user_data;            // User data pointer passed to mg_start()

  int num_headers;            // Number of HTTP headers
  struct mg_header {
    const char *name;         // HTTP header name
    const char *value;        // HTTP header value
  } http_headers[64];         // Maximum 64 headers
};
]]

-- helper
function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

--- HTML generation helpers.
function html(title, ...)
   return ([[
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html lang="en">
<head>
 <title>%s</title>
 <link rel="stylesheet" type="text/css" href="style.css">
</head>

<body>
%s
</body>
</html>
	   ]]):format(title, table.concat({...}, "\n"))
end

function h(text, num) return ('<h%d>%s</h%d>'):format(num, text, num) end

function color(color, text)
   return('<span style="color:%s;">%s</span>'):format(color, text)
end

function table_row(bdy)
   return ([[
<tr>
%s
</tr>
	   ]]):format(bdy)
end


function table_data(data) return ('<td>%s</td>'):format(data) end
function table_head(data) return ('<th>%s</th>'):format(data) end

function table_fill_row(data_tab, selected_rows)
   local out={}
   for _,rowname in ipairs(selected_rows) do
      out[#out+1]=table_data(data_tab[rowname])
   end
   return table_row(table.concat(out, "\n    "))
end

function table_fill_headline(selected_rows)
   local out={}
   for _,rowname in ipairs(selected_rows) do
      out[#out+1]=table_head(rowname)
   end
   return table_row(table.concat(out, "\n    "))
end




function reqinf_tostr(ri)
   return ([[
request method: %s <br>
uri:            %s <br>
http_version:   %s <br>
query_string:   %s <br>
remote_user:    %s <br>
<br>
<br>
generated on %s
   ]]):format(
      safe_ts(ri.request_method),
      safe_ts(ri.uri),
      safe_ts(ri.http_version),
      safe_ts(ri.query_string),
      safe_ts(ri.remote_user),
      os.date("%A %B %d, %Y, %X"))
end

--- Generate html tables of the known u5c types.
-- @param ni node_info
-- @return string containing html
function typelist_tohtml(ni)
   local table_header, table_footer, elem_per_tab
   local entries={}
   local output={}

   if u5c.num_types(ni) <= 0 then return "" end

   output[#output+1]="<h2>Registered types</h2>"

   table_header = [[
<table border="0" style="float:left; position:relative;" cellspacing="0" cellpadding="0">
  <tr>
   <th>name</th>
   <th>size (bytes)</th>
  </tr> ]]

   table_footer = '</table>'

   -- generate a single table entry and append it to entries
   local function gen_type_entry(t)
      entries[#entries+1]=
	 "<tr><td><tt>"..ffi.string(t.name).."</tt></td><td>"..tonumber(t.size).."</td></tr>"
   end

   -- generate list of entries
   u5c.types_foreach(ni, gen_type_entry)

   -- write then out in num_type_cols tables
   elem_per_tab = math.ceil(#entries/num_type_cols)

   local cnt=0

   output[#output+1]=table_header

   while cnt+1 <= #entries do
      if cnt~=0 and cnt % elem_per_tab == 0 then
	 output[#output+1]="\n\n\n"
	 output[#output+1]=table_footer
	 output[#output+1]=table_header
      end
      output[#output+1]=entries[cnt+1]
      cnt=cnt+1
   end

   output[#output+1]=table_footer
   output[#output+1]='<div style="clear:left"></div>'
   return table.concat(output, "\n")
end

--- Registered blocks
local block_headers = { 'name', 'state', 'prototype', 'stat_num_steps' }
function blocklist_tohtml(blklst, header)
   local table_header, table_footer, elem_per_tab
   local output={}

   if u5c.num_elements(blklst) <= 0 then return "" end

   table_header = [[
<table border="0" style="float:left; position:relative;" cellspacing="0" cellpadding="0">
      ]]

   table_footer = '</table>'

   local function colorize_state(t)
      if t.state=='preinit' then t.state=color("blue", t.state)
      elseif t.state=='inactive' then t.state=color("red", t.state)
      elseif t.state=='active' then t.state=color("green", t.state) end
      return t
   end
   -- generate a single table entry and append it to entries
   local function gen_block_tab_entry(t)
      output[#output+1]=table_fill_row(colorize_state(u5c.block_totab(t)), block_headers)
   end


   output[#output+1]=h(header, 2)
   output[#output+1]=table_header
   output[#output+1]=table_fill_headline(block_headers)

   -- generate list of entries
   u5c.blocks_foreach(blklst, gen_block_tab_entry)

   output[#output+1]=table_footer
   output[#output+1]='<div style="clear:left"></div>'
   return table.concat(output, "\n")
end


--- Stylesheet for the u5c webinterface
stylesheet_str=[[
body{
   background-color: #CCE5F0;
   color: #000000;
   font-size: 14px;
   margin: 10px;
   padding: 0;
   text-align: left;
   font-family: arial, verdana, sans-serif;
   font-weight:normal;
}

h1{ font-size: 24px; color: #000000; font-weight: normal; text-decoration: none; }
h2{ font-size:18px; color:#000000; font-weight:normal; }
a{ }
a:hover{ }

table {
   margin-right: 20px;
   /* margin: auto; */
}

th { padding-right: 20px; }
td { /* border: 0px solid #000000; */ }
td{ padding-right:10px; }

]]

function query_string_to_tab(qs)
   local res = {}
   local keyvals=split(qs, "&")
   for _,kv in ipairs(keyvals) do
      local k,v = string.match(kv, "^(%w+)=(%w+)$"); res[k]=v;
   end
   return res
end


local block_ops = {
   init=u5c.block_init,
   start=u5c.block_start,
   stop=u5c.block_stop,
   cleanup=u5c.block_cleanup
}

function process_GET(ri, ni)
   local qs_tab = query_string_to_tab(safe_ts(ri.query_string))
   for name,op in pairs(qs_tab) do
      local cb = u5c.cblock_get(ni, name)
      local ib = u5c.iblock_get(ni, name)
      local tb = u5c.tblock_get(ni, name)
      print(name, op, cb, ib, tb)
      if cb~=nil and block_ops[op] then print(op, name); block_ops[op](ni, cb) end
      if ib~=nil and block_ops[op] then print(op, name); block_ops[op](ni, ib) end
      if tb~=nil and block_ops[op] then print(op, name); block_ops[op](ni, tb) end
   end
end

--- master dispatch table.
dispatch_table = {
   ["/"] = function(ri, ni)
	      process_GET(ri, ni)
	      local title = ("u5c node: %s"):format(safe_ts(ni.name))
	      return html(
		 title,
		 h(title, 1),
		 blocklist_tohtml(ni.cblocks, "Computational blocks"),
		 blocklist_tohtml(ni.iblocks, "Interaction blocks"),
		 blocklist_tohtml(ni.tblocks, "Trigger blocks"),
		 typelist_tohtml(ni),
		 "<br><br>",
		 reqinf_tostr(ri))
	   end,

   ["/style.css"]=function() return stylesheet_str, "text/css" end,
}


function request_handler(node_info, request_info_lud)
   local reqinf = ffi.cast("struct mg_request_info*", request_info_lud)
   local ni = ffi.cast("struct u5c_node_info*", node_info)

   local uri = safe_ts(reqinf.uri)
   local handler = dispatch_table[uri]

   print("requesting uri", uri)

   if handler then return handler(reqinf, ni) end

   print("no handler found for uri", uri)
   return "<h1>no handler found</h1>"..reqinf_tostr(reqinf)
end

print("loaded request_handler()")