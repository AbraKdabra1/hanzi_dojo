import json
import os

# ==============================================================================
# AUDITORÍA DE NIVELES HSK (Estándar 3.0)
# ==============================================================================
# Aquí se definen los strings con los caracteres oficiales de cada nivel.
# Todo carácter que no esté en estos 7 niveles, pasará automáticamente al Nivel 10.

hsk_niveles = {
    1: "爱二姐年八饭今您爸房九牛吧飞觉女白非开朋百分看漂班服可苹半高客七包哥课期杯歌口起本个块气边给来千便工老前病公了钱不狗冷请菜关里去茶贵两热常国亮人唱果零认超还六日车孩妈三吃汉吗商出好买上穿号卖少床喝忙谁打和猫什大很么生蛋后没师到候妹十道话们时得欢米识的回面士弟会名市第火明事点机哪视电鸡那是东几奶手都家男书读间脑水对见呢睡多件能说儿叫你司四西样怎岁息要找他习也这它喜一真她系衣正太下医知题先宜只天现以中条想椅钟听小影住同校友桌外些有子玩写雨字晚谢语租喂新元昨文星院作问兴月坐我休再做五学在午雪早",
    2: "啊交晴希帮教球洗备介然笑比进让姓笔近肉颜表经色眼别睛绍药步酒身爷场就始已词咖试意次考室因从裤舒阴错快思泳但篮送游地乐诉右等累虽鱼店离所远懂留疼运动楼踢站啡路体长夫旅跳丈告绿铁周跟慢头着馆每完准过门万自黑拿网走红鸟往足花旁忘最画跑望左坏票为己妻位记情舞", # (Muestra HSK 2)
    3: "阿典环康矮调换渴安定黄刻把丢婚空般冬活哭搬短或筷板段激矿办锻级蓝饱朵极礼报饿急李北而季理被耳绩力必发加历变法假脸遍方坚练宾放检炼冰风简凉才封健辆参附讲聊草复蕉料层该角邻查概饺凌差感脚马尝干较码衬刚接满成糕街毛城根节冒迟更结末持共解目初故界南除顾借难楚瓜斤努处刮净爬船怪静怕春惯境拍聪海久盘答害旧胖带合居啤担河句片单乎据平当护决瓶灯化卡其奇收香用骑受箱邮汽瘦响又铅叔向于且束像羽轻树鞋育清数心遇秋刷信园求双行员区算熊愿趣糖须越全特需咱泉梯选脏裙提牙澡容甜言择如挺演展赛突羊张伞图阳照扫腿养者沙碗业直山卫页纸衫闻姨终烧屋议种勺务易重声物音主实戏银助史夏饮注世鲜应总适相迎嘴", 
    4: "按达膏即案待胳籍傲袋格计巴戴各纪败弹功技棒刀供际保导购济抱倒够既背登估继倍低姑寄笨底鼓价鼻递挂减毕掉观建标订管键饼堵光江并肚广将播度逛奖博断规降膊队咳郊部顿寒骄擦尔喊巾猜翻汗金材烦航仅彩反何尽餐费盒紧操份贺禁厕奋厚京察丰呼惊产否忽精厂肤虎景晨符互警诚幅户竞乘福划竟程父怀镜厨付悔究础负伙举窗傅货拒吹富获具此改圾剧粗赶积距村敢基聚存钢及绝烤秒琴死科民青松棵命庆嗽克默取速肯母缺塑恐慕却酸苦耐确随况恼染孙困闹扰台垃内任拉嗯扔态辣娘仍谈懒农入汤浪弄散躺厉暖森趟丽偶伤萄励排稍讨利牌社套例判摄堂俩乓申填连陪深厅联批甚庭谅皮省停量脾剩通列篇失童林频拾桶龄品食痛另聘使土流乒氏推乱评示脱论泼式袜落破柿危律葡释微虑普匙围麻戚首味馒弃授温漫签售污帽歉输无貌强熟误美敲暑吸梦桥术悉迷巧帅惜密切顺细免亲硕咸险研愉值线盐与职羡厌预植乡验原止详扬约址项洋阅指象邀云至消钥允志效叶杂质辛夜仔众醒疑暂洲幸艺则祝性忆责著兄译增专修谊章转羞引账赚秀印招装许赢折资序永针族续勇争组血优整尊压幽证座亚尤之烟由支严油汁",
    5: "哎翅仿汇唉冲访惠暗充肥慧熬虫纷祸版宠疯肌扮抽扶疾伴丑佛集膀臭府辑傍触腐挤薄传妇迹宝创副佳暴辞盖嘉贝刺搞甲彼促革驾币催隔架闭措恭艰避代贡捡拨胆沟剪玻旦构荐补淡古渐布挡固践裁档冠浆采蹈瑰浇藏敌柜阶册蝶滚届测冻锅谨曾洞裹敬叉斗哈救插豆含局拆独憾橘倡堆衡巨朝吨猴捐吵盾胡卷炒躲湖军彻乏蝴均沉罚糊靠称番华颗承繁滑控橙返缓扣池泛灰库尺范挥宽齿防恢款狂模润索亏陌弱锁昆漠洒桃扩某傻替括木厦挑览幕晒贴郎奈删统劳念扇投姥浓善途泪哦擅兔类欧赏团厘派蛇退梨培舍拖璃赔设弯立配伸威恋盆神违良碰慎唯粮匹升维疗骗胜伟烈拼诗尾临凭施未灵屏湿胃铃婆石慰领齐驶稳令企似卧浏器势握龙浅饰伍漏欠守武陆墙殊雾录抢蔬夕碌悄属析逻茄鼠席络勤述闲率穷摔显骂曲税县矛趋私限玫权搜献媒劝俗厢魅群肃享秘燃素橡眠绕宿销描忍碎肖敏荣软缩协胁斜乙赞制欣亿糟治形义造致型益赠智虚营炸置绪映摘猪宣硬窄竹寻拥占逐询悠战煮训犹涨筑迅幼掌抓押余召状鸭娱哲撞呀玉珍追延域诊咨沿喻阵姿腰寓震紫摇豫征综咬圆挣阻依源政醉移怨织遵遗载执", # Pegar lista HSK 5
    6: "碍储氛恨岸串粉横昂闯愤宏拔垂峰虹摆纯蜂洪拜瓷奉壶榜匆浮幻胞醋辅患爆脆赋皇悲寸覆绘辈挫尬混奔搭肝惑逼呆尴击壁贷岗饥臂耽港吉编诞稿寂兵岛割夹脖稻攻嫁捕德宫稼财滴巩尖踩抵孤肩残帝股监仓吊骨兼侧钓拐剑策跌官鉴柴顶贯箭肠栋罐酱偿逗归胶畅督龟椒抄毒轨焦嘲渡跪杰潮端棍洁撤蹲涵捷臣夺罕截尘额旱戒趁恶毫劲撑帆豪井呈凡耗颈惩犯核径崇妨嘿纠愁肪痕舅筹肺狠菊矩煤渠铜俱弥娶筒惧蜜圈偷菌棉券透刊勉壤徒砍妙绒吐抗灭融吞枯摩柔托酷寞撒挖夸纳塞娃馈泥嗓哇阔拟丧歪啦扭杀顽赖怒刹亡兰诺鲨王拦盼筛委栏庞闪谓烂抛尚沃狼泡舌乌廊佩射晰朗喷涉媳牢捧审吓雷披甥嫌粒疲盛陷怜飘狮祥链贫寿宵梁坡薯歇晾迫竖谐劣扑漱携淋朴衰械笼铺瞬薪露欺艘胸轮棋塔雄履旗踏袖略启汰叙蚂恰坛蓄嘛牵探旋埋谦碳旬迈潜烫循麦枪掏讯盲腔逃讶贸瞧淘淹眉倾添炎梅屈田艳宴涌粘株央忧崭诸仰予仗砖氧浴障妆痒欲枕庄遥裕镇壮野誉睁椎液援症捉仪跃枝棕蚁晕脂踪异匀侄粽抑孕殖奏疫灾秩祖姻遭肿钻隐噪州罪英燥粥婴扎骤颖宅珠", # Pegar lista HSK 6
    7: "哀鄙嘈矗挨庇槽揣癌毙蹭踹蔼痹岔川艾碧诧喘隘蔽掺幢暧弊搀炊凹鞭馋捶奥贬禅锤扒扁缠唇叭辨铲淳芭辩阐醇疤辫颤蠢靶飙昌戳坝憋猖绰罢彬敞疵霸滨钞慈掰缤巢磁柏濒扯雌扳丙澈伺颁秉辰赐斑柄陈囱拌波澄葱绊剥逞丛瓣伯秤凑绑驳痴簇谤勃弛窜磅舶驰摧煲搏侈璀褒簸耻悴雹卜斥粹堡哺赤翠豹怖憧搓卑睬仇磋碑惭绸瘩狈惨畴歹惫灿酬逮焙璨稠怠崩苍瞅丹绷沧锄惮迸舱橱党蹦糙畜荡叨妒辐鬼捣兑抚桂祷敦斧骇盗盹俯酣悼炖咐憨蹬钝赴函凳哆腹捍瞪舵缚撼堤堕丐瀚迪惰钙夯涤讹溉浩笛鹅甘呵嘀厄杆禾蒂遏竿阂缔噩纲荷颠鳄缸赫巅恩杠鹤甸饵戈哼垫伐疙恒淀阀鸽轰惦贩搁哄奠坊阁烘殿芳骼弘刁纺耕喉叼绯耿吼凋匪哽狐雕诽弓唬爹废躬哗迭沸拱猾谍芬勾徊叠吩钩槐碟坟苟唤丁焚咕焕叮粪菇痪盯锋辜荒钉逢谷慌鼎讽雇凰董凤寡煌兜缝卦恍抖孵乖晃陡敷棺谎赌伏灌辉睹俘闺徽杜袱诡毁卉矫慨唠讳搅楷涝贿缴勘酪秽轿堪勒昏酵坎垒荤皆侃磊浑揭槛蕾魂劫慷棱豁竭扛愣霍诫苛狸讥津磕黎缉筋壳鲤畸锦坷吏稽晋垦隶汲浸恳莉棘茎啃莅嫉荆坑帘脊晶吭莲忌兢孔廉剂鲸抠敛祭阱窟辽暨憬垮僚颊窘挎寥贾揪跨潦奸灸筐咧歼拘旷猎煎鞠框裂拣咀眶拎柬沮窥麟俭炬魁吝贱倦溃赁舰诀愧陵溅抉捆聆姜倔廓岭僵掘喇溜疆崛腊瘤桨嚼蜡柳匠君睐遛娇钧婪咙跤俊澜胧礁峻揽聋侥骏缆隆狡竣滥窿绞凯捞拢垄眯腻譬搂谜溺偏陋觅黏撇炉泌撵坪卤绵酿萍虏缅尿泊鲁腼捏颇赂苗宁粕鹿瞄拧魄孪渺凝剖卵藐泞仆抡庙纽菩伦蔑钮谱啰鸣奴瀑罗铭虐曝萝谬挪沏螺膜殴栖裸磨呕凄侣蘑趴漆屡魔帕蹊缕抹徘歧滤茉湃祈掠沫攀崎脉莫叛乞蛮墨畔岂瞒谋螃迄蔓牡刨泣芒亩袍契氓拇炮砌茫姆胚掐莽沐沛洽髦牧抨迁茂募烹虔枚墓棚遣霉睦蓬谴昧暮鹏嵌寐呐澎呛媚乃篷跷闷囊膨侨萌挠劈憔蒙馁屁俏盟嫩辟峭朦逆媲窍猛匿僻翘撬煽祀剔怯膳饲屉窃赡肆剃惬裳怂涕锲捎耸惕钦梢讼嚏侵哨诵腆禽奢颂舔寝慑苏眺擎呻酥帖顷绅溯廷丘肾蒜亭囚渗髓艇岖牲隧捅驱绳邃凸躯圣唆秃诠尸梭涂拳蚀嗦屠犬矢琐颓瘸屎塌豚雀侍拓臀攘逝蹋驮嚷嗜胎妥饶誓泰椭惹兽贪唾仁抒摊蛙韧枢滩瓦饪梳瘫湾溶疏痰丸冗赎潭挽揉署坦惋乳曙毯婉辱恕叹腕锐墅炭汪瑞耍唐枉若甩塘妄萨拴膛旺桑涮倘帷骚霜淌伪嫂爽涛纬涩烁滔萎啬丝陶畏僧撕腾蔚纱寺藤瘟纹宪炫役蚊馅削绎吻镶靴弈紊翔穴逸翁巷勋裔涡萧熏溢窝潇巡毅幄嚣汛翼呜淆驯荫诬晓逊殷侮孝丫吟捂啸鸦瘾兀邪芽鹰勿挟崖荧悟泄涯盈晤泻哑莹昔卸雅蝇牺屑揠佣奚懈岩庸稀蟹阎恿犀芯檐踊锡馨衍佑溪衅掩诱熙猩咽淤熄腥雁渔膝刑焰逾嬉凶燕愚袭汹殃舆徙朽秧屿隙绣杨宇虾锈漾驭瞎嗅妖郁侠吁肴狱峡墟窑御狭徐谣愈瑕旭耀冤辖恤椰渊霞酗冶缘仙絮夷辕纤婿怡曰掀喧矣岳贤暄倚悦弦玄屹耘衔悬亦陨酝沾拯瞩韵瞻郑贮蕴斩芝驻熨盏肢柱砸辗旨蛀栽绽帜铸宰湛峙拽攒蘸挚撰赃彰掷桩葬杖窒坠凿帐滞缀凿账稚赘藻爪忠拙皂沼衷灼灶兆仲茁躁罩舟卓泽肇轴浊贼遮帚酌渣辙宙兹闸贞昼滋眨侦皱籽诈斟朱宗榨振烛纵债筝拄揍寨蒸嘱琢" 
}

def clasificar_diccionario(archivo_entrada, archivo_salida, archivo_excluidos):
    import os
    print("==================================================")
    print(f" Iniciando auditoría de Hanzi...")
    print(f" Archivo fuente: {archivo_entrada}")
    print("==================================================\n")
    
    if not os.path.exists(archivo_entrada):
        print(f"[ERROR CRÍTICO] No se encontró el archivo '{archivo_entrada}'.")
        return

    try:
        with open(archivo_entrada, 'r', encoding='utf-8') as f:
            diccionario = json.load(f)
    except json.JSONDecodeError:
        print(f"[ERROR CRÍTICO] El archivo '{archivo_entrada}' no es un JSON válido.")
        return

    caracteres_procesados = 0
    conteo_niveles = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 10:0}
    
    # Lista para atrapar a los que no pasen el filtro
    hanzi_no_oficiales = []
    
    for item in diccionario:
        caracter = item.get('simplificado', '')
        nivel_asignado = 10  # Default: Nivel 10

        for nivel, lista_caracteres in hsk_niveles.items():
            if caracter in lista_caracteres:
                nivel_asignado = nivel
                break

        # Si se quedó en 10, lo guardamos en nuestra lista de excluidos
        if nivel_asignado == 10 and caracter:
            hanzi_no_oficiales.append(caracter)

        item['nivel'] = nivel_asignado
        conteo_niveles[nivel_asignado] += 1
        caracteres_procesados += 1

    # Guardar el JSON principal
    with open(archivo_salida, 'w', encoding='utf-8') as f:
        json.dump(diccionario, f, ensure_ascii=False, indent=2)

    # Exportar el TXT con los caracteres raros/no oficiales
    if hanzi_no_oficiales:
        with open(archivo_excluidos, 'w', encoding='utf-8') as f:
            # Los guardamos uno por línea para que sea fácil de leer
            f.write("\n".join(hanzi_no_oficiales))

    print("\n==================================================")
    print(" REPORTE FINAL DE CLASIFICACIÓN")
    print("==================================================")
    print(f" ✅ Total procesados: {caracteres_procesados}")
    print(f" 📁 JSON generado: {archivo_salida}")
    if hanzi_no_oficiales:
        print(f" 📄 Log de excluidos: {archivo_excluidos} ({len(hanzi_no_oficiales)} caracteres)")
    print("\n Distribución:")
    for n in sorted(conteo_niveles.keys()):
        etiqueta = "HSK 7-9 (Avanzado)" if n == 7 else "No Oficial / Raros" if n == 10 else f"HSK {n}"
        print(f"  - {etiqueta}: {conteo_niveles[n]}")
    print("==================================================")

if __name__ == "__main__":
    entrada = 'diccionario_supercargado.json'
    salida = 'diccionario_hsk_final.json'
    excluidos = 'hanzi_no_clasificados.txt'
    
    clasificar_diccionario(entrada, salida, excluidos)