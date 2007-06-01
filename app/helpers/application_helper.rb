# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
   def style_for_tag_cloud( total, lowest, highest, options={} )
     return nil if total.nil? or highest.nil? or lowest.nil?
     #
     # options
     maxf = options.delete( :max_font_size ) || 20
     minf = options.delete( :min_font_size ) || 10
     maxc = options.delete( :max_color )     || [ 50, 80, 90 ]
     minc = options.delete( :min_color )     || [ 170, 196, 156 ]
     hide_sizes   = options.delete( :hide_sizes )
     hide_colours = options.delete( :hide_colours )
     #
     # function to work out rgb values
     def rgb_color( a, b, i, x)
        return nil if i <= 1 or x <= 1
        if a > b
         a-(Math.log(i)*(a-b)/Math.log(x)).floor
        else
         (Math.log(i)*(b-a)/Math.log(x)+a).floor
        end
     end
     #
     # work out colours
     c = []
     (0..2).each { |i| c << rgb_color( minc[i], maxc[i], total, highest ) || nil }
     colors = c.compact.empty? ? minc.join(',') : c.join(',')
     #
     # work out the font size
     spread = highest.to_f - lowest.to_f
     spread = 1.to_f if spread <= 0
     fontspread = maxf.to_f - minf.to_f
     fontstep = spread / fontspread
     size = ( minf + ( total.to_f / fontstep ) ).to_i
     size = maxf if size > maxf
     #
     # display the results
     size_txt = "font-size:#{ size.to_s }px;" unless hide_sizes
     color_txt = "color:rgb(#{ colors });" unless hide_colours
     return [ size_txt, color_txt ].join
   end
end
